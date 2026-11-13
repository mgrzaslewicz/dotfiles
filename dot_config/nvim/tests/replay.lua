-- Contracts and their replay (vocabulary: GLOSSARY.md, decision: docs/adr/0001). A contract holds the responses of one
-- real server to the requests of the replayed tests on one fixture: `tests/contracts/<fixture>.<server>.json`, with
-- the server's pinned version, a hash of the fixture tree and one recording per request. Paths of the machine that
-- recorded (the fixture copy, the e2e state dir, $HOME) are stored as placeholders.
--
-- The replayed tests, `tests/test_replay_<fixture>.lua`, run in one of three modes (CONTRACT_MODE):
--  - replay (layer A, the default): no server. `request_all` of custom/implementations, the LSP request seam of the
--    config's features, answers from the contracts; a request without a recording fails the test, and so does a
--    fixture changed since the recording.
--  - smoke (`tests/run.sh --smoke`): the same tests against the real servers, which catches server drift.
--  - record (`tests/run.sh --record`): smoke, and every request the tests send is recorded. A contract is rewritten
--    only when every request to it was answered and every case using it passed; otherwise it is left as it was. The
--    run lists each recorded request and each failure.
--
-- Loaded in the test runner and, by `dofile`, in the child (`install`); no side effects on load.

local M = {}

local source = debug.getinfo(1, 'S').source:sub(2)
M.root = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(source, ':p')))
M.fixtures_dir = vim.fs.joinpath(M.root, 'tests', 'e2e', 'fixtures')
M.contracts_dir = vim.fs.joinpath(M.root, 'tests', 'contracts')

-- LSP client name → Mason package, whose pin in custom/tools.lua is the contract's server version.
M.servers = { jdtls = 'jdtls', kotlin_lsp = 'kotlin-lsp' }

local RECORD_HINT = 'record it with `tests/run.sh --record`'

---@return 'replay'|'smoke'|'record'
function M.mode() return vim.env.CONTRACT_MODE or 'replay' end

--- JSON with object keys sorted at every level, so that equal values always encode the same: request keys, and
--- contract files whose diffs show only changed answers. An empty table is a list. With `indent`, pretty-printed.
---@param value any
---@param indent? string
---@return string
function M.encode(value, indent)
  local function enc(v, depth)
    if v == nil or v == vim.NIL then return 'null' end
    if type(v) ~= 'table' then return vim.json.encode(v) end
    local nl = indent and ('\n' .. indent:rep(depth + 1)) or ''
    local close = indent and ('\n' .. indent:rep(depth)) or ''
    local sep = indent and ': ' or ':'
    local parts = {}
    if vim.tbl_isempty(v) then return '[]' end
    if vim.islist(v) then
      for _, item in ipairs(v) do
        table.insert(parts, nl .. enc(item, depth + 1))
      end
      return '[' .. table.concat(parts, ',') .. close .. ']'
    end
    local keys = vim.tbl_keys(v)
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      table.insert(parts, nl .. vim.json.encode(tostring(k)) .. sep .. enc(v[k], depth + 1))
    end
    return '{' .. table.concat(parts, ',') .. close .. '}'
  end
  return enc(value, 0)
end

---@param text string
function M.decode(text) return vim.json.decode(text, { luanil = { object = true, array = true } }) end

--- The key of a request in a contract: the method, a space, the params as canonical JSON.
---@param method string
---@param params table
---@return string
function M.key(method, params) return method .. ' ' .. M.encode(params) end

--- `text` with every occurrence of `from` replaced by `to`, literally.
local function replace(text, from, to)
  local out, start = {}, 1
  while true do
    local i, j = text:find(from, start, true)
    if not i then break end
    table.insert(out, text:sub(start, i - 1))
    table.insert(out, to)
    start = j + 1
  end
  table.insert(out, text:sub(start))
  return table.concat(out)
end

--- Placeholders and the paths they stand for in this process: the fixture copy, the state dir of the test run
--- (Mason, plugins, Gradle/Maven caches), $HOME. Most specific first.
---@param project string the fixture copy
---@return {[1]: string, [2]: string}[]
function M.roots(project)
  local roots = { { '${fixture}', project } }
  local real = vim.uv.fs_realpath(project)
  if real and real ~= project then table.insert(roots, { '${fixture}', real }) end
  if vim.env.XDG_DATA_HOME then table.insert(roots, { '${state}', vim.fs.dirname(vim.env.XDG_DATA_HOME) }) end
  if vim.env.HOME then table.insert(roots, { '${home}', vim.env.HOME }) end
  return roots
end

--- `value` with the paths of `roots` replaced by their placeholders, in every string.
---@generic T
---@param value T
---@param roots {[1]: string, [2]: string}[]
---@return T
function M.generalize(value, roots)
  if value == nil then return nil end
  local text = M.encode(value)
  for _, root in ipairs(roots) do
    text = replace(text, root[2], root[1])
  end
  return M.decode(text)
end

--- `value` with the placeholders of `roots` replaced by their paths.
---@generic T
---@param value T
---@param roots {[1]: string, [2]: string}[]
---@return T
function M.localize(value, roots)
  if value == nil then return nil end
  local text = M.encode(value)
  local done = {}
  for _, root in ipairs(roots) do
    if not done[root[1]] then
      done[root[1]] = true
      text = replace(text, root[1], root[2])
    end
  end
  return M.decode(text)
end

-- Not part of a fixture: build output, Gradle's cache, what jdtls writes into a project it imports, and the fixture's
-- README (no server reads it, so editing it does not make the contracts stale).
local IGNORED = {
  build = true,
  target = true,
  bin = true,
  ['.gradle'] = true,
  ['.kotlin'] = true,
  ['.settings'] = true,
  ['.project'] = true,
  ['.classpath'] = true,
  ['README.md'] = true,
}

--- SHA-256 of a fixture tree: every file's relative path and content, in path order, minus what IGNORED names.
---@param dir string
---@return string
function M.fixture_hash(dir)
  local files = {}
  local function walk(rel)
    for name, type in vim.fs.dir(vim.fs.joinpath(dir, rel)) do
      local path = rel == '' and name or (rel .. '/' .. name)
      if not IGNORED[name] then
        if type == 'directory' then
          walk(path)
        else
          table.insert(files, path)
        end
      end
    end
  end
  walk ''
  table.sort(files)
  local parts = {}
  for _, path in ipairs(files) do
    local f = assert(io.open(vim.fs.joinpath(dir, path), 'rb'))
    table.insert(parts, path .. '\0' .. f:read '*a' .. '\0')
    f:close()
  end
  return vim.fn.sha256(table.concat(parts))
end

---@class replay.Opts
---@field fixtures? string dir of the fixtures, default tests/e2e/fixtures
---@field contracts? string dir of the contracts, default tests/contracts
---@field mode? 'replay'|'smoke'|'record' for `session`, default `M.mode()`
---@field store? table for `session` in record mode, default `M.store`

---@param fixture string
---@param server string LSP client name
---@param opts? replay.Opts
---@return string
function M.path(fixture, server, opts) return vim.fs.joinpath((opts or {}).contracts or M.contracts_dir, ('%s.%s.json'):format(fixture, server)) end

--- Writes `contract` to `path`: its recordings sorted by key, pretty-printed.
---@param path string
---@param contract table
function M.write(path, contract)
  local recordings = vim.deepcopy(contract.recordings)
  table.sort(recordings, function(a, b) return M.key(a.method, a.params) < M.key(b.method, b.params) end)
  local out = vim.tbl_extend('force', contract, { recordings = recordings })
  out.index = nil
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile(vim.split(M.encode(out, '  '), '\n'), path)
end

--- The contract of `server` on `fixture`, with `index` (key → recording). Fails when there is none, or when the
--- fixture changed since it was recorded.
---@param fixture string
---@param server string
---@param opts? replay.Opts
function M.load(fixture, server, opts)
  local path = M.path(fixture, server, opts)
  if vim.fn.filereadable(path) == 0 then error(('no contract %s; %s'):format(vim.fs.basename(path), RECORD_HINT), 0) end
  local contract = M.decode(table.concat(vim.fn.readfile(path), '\n'))
  local hash = M.fixture_hash(vim.fs.joinpath((opts or {}).fixtures or M.fixtures_dir, fixture))
  if contract.fixture_hash ~= hash then
    error(('contract %s is stale: fixture %s changed since it was recorded; re-%s'):format(vim.fs.basename(path), fixture, RECORD_HINT), 0)
  end
  contract.index = {}
  for _, rec in ipairs(contract.recordings or {}) do
    contract.index[M.key(rec.method, rec.params)] = rec
  end
  return contract
end

--- In the child: replaces the LSP request seam. `state.mode` replay answers from `state.index` (key → recording);
--- record sends to the real servers and keeps each request and the answer of the session's server in
--- `_G.replay.captured`. `state.roots` are the child's placeholders.
---@param state {mode: string, index?: table, roots: table, servers: string[], fixture: string}
function M.install(state)
  local impl = require 'custom.implementations'
  _G.replay = { misses = {}, captured = {} }
  --- `file:line` of a location, the file relative to the cwd (the fixture copy), for assertions.
  function _G.replay.location(l) return vim.fs.relpath(vim.fn.getcwd(), vim.uri_to_fname(l.uri)) .. ':' .. (l.range.start.line + 1) end
  if state.mode == 'replay' then
    ---@diagnostic disable-next-line: duplicate-set-field
    impl.request_all = function(method, params, callback)
      local key = M.key(method, M.generalize(params, state.roots))
      local rec = state.index[key]
      if not rec then
        table.insert(_G.replay.misses, ('no recording of %s in %s; %s'):format(key, state.fixture, RECORD_HINT))
        return function() end
      end
      local result = M.localize(rec.result, state.roots)
      vim.schedule(function() callback(impl.results { { result = result } }) end)
      return function() end
    end
    return
  end
  ---@diagnostic disable-next-line: duplicate-set-field
  impl.request_all = function(method, params, callback, bufnr)
    bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
    -- A recording is one server's answer, so a request two of the session's servers answer cannot be recorded.
    local clients = vim.tbl_filter(function(c) return vim.tbl_contains(state.servers, c.name) end, vim.lsp.get_clients { bufnr = bufnr })
    local client = #clients == 1 and clients[1] or nil
    local entry = { server = client and client.name, method = method, params = M.generalize(params, state.roots), pending = true }
    table.insert(_G.replay.captured, entry)
    if not client then
      entry.pending = nil
      entry.error = ('%d of %s attached to %s, a recording needs exactly one'):format(
        #clients,
        table.concat(state.servers, '/'),
        vim.api.nvim_buf_get_name(bufnr)
      )
    end
    return vim.lsp.buf_request_all(bufnr, method, params, function(responses)
      local response = client and responses[client.id]
      if client then
        entry.pending = nil
        if not response then
          entry.error = 'no answer from ' .. client.name
        elseif response.err then
          entry.error = ('%s answered with an error: %s'):format(client.name, response.err.message or vim.inspect(response.err))
        else
          entry.result = M.generalize(response.result, state.roots)
        end
      end
      callback(impl.results(responses))
    end)
  end
end

-- Record mode: contract path → { fixture, server, recordings = { key → recording }, failures = { string } }, filled
-- after each case, written by `finish_recording`.
M.store = {}

--- Adds what a live case sent (`captured`, from the child) to `store`. A request without an answer, or answered with
--- an error, is a failure of its contract; so is a failed case, for every contract of its session.
---@param store table
---@param fixture string
---@param servers string[]
---@param captured table[]
---@param case_failed string? the case's name when it failed
---@param opts? replay.Opts
function M.collect(store, fixture, servers, captured, case_failed, opts)
  local function contract(server)
    local path = M.path(fixture, server, opts)
    store[path] = store[path] or { fixture = fixture, server = server, recordings = {}, failures = {} }
    return store[path]
  end
  for _, server in ipairs(servers) do
    local c = contract(server)
    if case_failed then table.insert(c.failures, 'case failed: ' .. case_failed) end
  end
  for _, entry in ipairs(captured) do
    local key = M.key(entry.method, entry.params)
    if entry.server == nil then
      for _, server in ipairs(servers) do
        table.insert(contract(server).failures, ('%s: %s'):format(key, entry.error))
      end
    else
      local c = contract(entry.server)
      if entry.pending then
        table.insert(c.failures, key .. ': no answer before the case ended')
      elseif entry.error then
        table.insert(c.failures, ('%s: %s'):format(key, entry.error))
      else
        c.recordings[key] = { method = entry.method, params = entry.params, result = entry.result }
      end
    end
  end
end

--- Writes each contract of `store` without failures, with the pinned server version and the fixture's hash, and
--- leaves the others as they are. Prints what was recorded and what failed; returns whether nothing failed.
---@class replay.FinishOpts: replay.Opts
---@field version? fun(server: string): string the pinned version of a server, default from custom/tools.lua
---@field print? fun(line: string) default stdout

---@param store table
---@param opts? replay.FinishOpts
---@return boolean
function M.finish_recording(store, opts)
  opts = opts or {}
  local version = opts.version or function(server) return require('custom.tools').version(M.servers[server]) end
  local out = opts.print or function(line) io.stdout:write(line, '\n') end
  local ok = true
  local paths = vim.tbl_keys(store)
  table.sort(paths)
  for _, path in ipairs(paths) do
    local c = store[path]
    local name = vim.fs.basename(path)
    if #c.failures > 0 then
      ok = false
      out(('kept %s unchanged, %d failure(s):'):format(name, #c.failures))
      for _, failure in ipairs(c.failures) do
        out('  failed ' .. failure)
      end
    else
      local keys = vim.tbl_keys(c.recordings)
      table.sort(keys)
      out(('recorded %s, %d request(s):'):format(name, #keys))
      for _, key in ipairs(keys) do
        out('  ' .. key)
      end
      M.write(path, {
        fixture = c.fixture,
        server = c.server,
        server_version = version(c.server),
        fixture_hash = M.fixture_hash(vim.fs.joinpath(opts.fixtures or M.fixtures_dir, c.fixture)),
        recordings = vim.tbl_values(c.recordings),
      })
    end
  end
  return ok
end

--- MiniTest set of replayed tests on one fixture, one child for the whole file, like layer B's `fixture_set`.
--- `servers` names the session's servers, each with how to tell it has indexed the project, which only live modes
--- use: go-to-definition on `symbol` in `file` reaches a file ending in `target`. `jdk = true` also waits for a JDK class
--- (java.util.ArrayList) to resolve, for the fixtures whose JDK tests run against the live server.
---
--- `ctx.child`; `ctx.project` (the fixture copy); `ctx.edit(path)` opens a file of it (live: waits for a server);
--- `ctx.cursor(text, offset?)` puts the cursor on a text of the current buffer, `ctx.position()` says where it is;
--- `ctx.capture_pick()` keeps what the implementations picker gets in the child's `_G.picked`; `_G.replay.location(l)`
--- in the child is a location as `file:line`;
--- `ctx.wait(what, condition)` waits for a Lua condition in the child (replay: a few seconds, failing at once on a
--- request without recording; live: the `index` timeout of layer B). `ctx.hooks` are the set's hooks.
---@param fixture string
---@param servers table<string, {file: string, symbol: string, target: string, jdk: boolean?}>
---@param opts? replay.Opts
function M.session(fixture, servers, opts)
  local helpers = require 'tests.helpers'
  local e2e = require 'tests.e2e.helpers'
  local mode = (opts or {}).mode or M.mode()
  local names = vim.tbl_keys(servers)
  table.sort(names)
  local ctx = { child = helpers.new_child() }
  local child = ctx.child
  local load_error

  local function misses() return child.lua_get '_G.replay and _G.replay.misses or {}' end

  function ctx.edit(path)
    child.cmd('edit ' .. path)
    if mode == 'replay' then return end
    local any = ('vim.iter(vim.lsp.get_clients { bufnr = 0 }):any(function(c) return vim.tbl_contains(%s, c.name) end)'):format(vim.inspect(names))
    e2e.wait(child, 'attach', ('a %s client attached to %s'):format(table.concat(names, '/'), path), any)
  end

  --- Puts the cursor on the first `text` in the current buffer, `offset` bytes into it.
  function ctx.cursor(text, offset)
    child.lua(
      [[
      local text, offset = ...
      for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        local col = line:find(text, 1, true)
        if col then return vim.api.nvim_win_set_cursor(0, { i, col - 1 + offset }) end
      end
      error(text .. ' not in buffer')
    ]],
      { text, offset or 0 }
    )
  end

  --- Where the cursor is: the file relative to the project, the 1-based line and the 0-based column.
  function ctx.position() return child.lua_get '{ vim.fs.relpath(vim.fn.getcwd(), vim.api.nvim_buf_get_name(0)), unpack(vim.api.nvim_win_get_cursor(0)) }' end

  --- Until the end of the case, the implementations picker keeps what it is given in the child's `_G.picked`:
  --- `{ title, { file:line } }`.
  function ctx.capture_pick()
    child.lua [[
      local impl = require 'custom.implementations'
      _G.picked, _G.pick_before = nil, impl.pick
      impl.pick = function(locations, title) _G.picked = { title, vim.tbl_map(_G.replay.location, locations) } end
    ]]
    MiniTest.finally(function() child.lua "require('custom.implementations').pick = _G.pick_before" end)
  end

  function ctx.wait(what, condition)
    if mode ~= 'replay' then return e2e.wait(child, 'index', what, condition) end
    local deadline = vim.uv.now() + 5000
    repeat
      local missed = misses()
      if #missed > 0 then error(table.concat(missed, '\n'), 0) end
      if child.lua(('return (%s) and true or false'):format(condition)) then return end
      vim.wait(10)
    until vim.uv.now() > deadline
    error('timed out after 5 s waiting for: ' .. what, 0)
  end

  ctx.hooks = {
    pre_once = function()
      local fixture_dir = vim.fs.joinpath((opts or {}).fixtures or M.fixtures_dir, fixture)
      local dir = vim.fn.tempname()
      vim.fn.mkdir(dir, 'p')
      local copied = vim.system({ 'cp', '-R', fixture_dir, dir }):wait()
      assert(copied.code == 0, copied.stderr)
      ctx.project = vim.uv.fs_realpath(vim.fs.joinpath(dir, fixture))
      local index = {}
      if mode == 'replay' then
        local ok, err = pcall(function()
          for _, server in ipairs(names) do
            index = vim.tbl_extend('error', index, M.load(fixture, server, opts).index)
          end
        end)
        if not ok then load_error = err end
      end
      child.start()
      child.cmd('cd ' .. ctx.project)
      -- The test child has no clipboard tool: a provider that keeps `+` in memory.
      child.lua [[
        local function copy(lines) _G.clip = lines end
        local function paste() return _G.clip or {} end
        vim.g.clipboard = { name = 'test', copy = { ['+'] = copy, ['*'] = copy }, paste = { ['+'] = paste, ['*'] = paste } }
      ]]
      if mode ~= 'replay' then
        ctx.workspace = vim.fs.joinpath(child.lua_get "vim.fn.stdpath 'cache'", 'jdtls', (ctx.project:gsub('[/\\:]', '_')))
        for _, server in ipairs(names) do
          local probe = servers[server]
          child.cmd('edit ' .. probe.file)
          e2e.wait(child, 'attach', server .. ' attached', ('#vim.lsp.get_clients { bufnr = 0, name = %q } > 0'):format(server))
          e2e.definition_reaches(child, probe.symbol, probe.target)
          if probe.jdk then
            -- The project resolves before the JDK index is ready: a JDK class answered empty until ~30 s in (v271).
            child.lua "vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'val probe = java.util.ArrayList<String>()' })"
            e2e.definition_reaches(child, 'ArrayList', 'ArrayList.class')
          end
        end
        child.cmd 'silent! %bdelete!'
      end
      child.lua(
        [[
        local root, state = ...
        state.roots = dofile(root .. '/tests/replay.lua').roots(vim.fn.getcwd())
        dofile(root .. '/tests/replay.lua').install(state)
      ]],
        { M.root, { mode = mode == 'replay' and 'replay' or 'record', index = index, servers = names, fixture = fixture } }
      )
    end,
    pre_case = function()
      if load_error then error(load_error, 0) end
    end,
    -- bdelete, not bwipeout: nvim-jdtls keeps buffer ids and fails on wiped buffers.
    post_case = function()
      if not child.is_running() then return end
      local missed = mode == 'replay' and misses() or {}
      if mode == 'record' then
        local case = MiniTest.current.case
        local failed = case and #case.exec.fails > 0 and table.concat(case.desc, ' | ') or nil
        M.collect((opts or {}).store or M.store, fixture, names, child.lua_get '_G.replay and _G.replay.captured or {}', failed, opts)
      end
      child.lua 'if _G.replay then _G.replay.misses, _G.replay.captured = {}, {} end'
      child.cmd 'silent! %bdelete!'
      if #missed > 0 then error(table.concat(missed, '\n'), 0) end
    end,
    post_once = function()
      child.stop()
      if ctx.workspace then vim.fn.delete(ctx.workspace, 'rf') end
    end,
  }
  return MiniTest.new_set { hooks = ctx.hooks }, ctx
end

--- Entry point of `tests/run.sh --smoke` and `--record`: the replayed tests (or `file`) against the real servers;
--- record mode then writes the contracts (see `finish_recording`). Exits non-zero on a failed case or recording.
---@param file string
function M.run_live(file)
  local stdout = MiniTest.gen_reporter.stdout { quit_on_finish = false }
  local reporter = vim.tbl_extend('force', stdout, {
    finish = function()
      stdout.finish()
      local ok = true
      if M.mode() == 'record' then
        io.stdout:write '\n'
        ok = M.finish_recording(M.store)
      end
      local failed = vim.iter(MiniTest.current.all_cases or {}):any(function(c) return c.exec and #c.exec.fails > 0 end)
      vim.cmd(('silent! %dcquit'):format((failed or not ok) and 1 or 0))
    end,
  })
  local files = file ~= '' and { file } or vim.fn.globpath('tests', 'test_replay_*.lua', true, true)
  MiniTest.run { collect = { find_files = function() return files end }, execute = { reporter = reporter } }
end

return M
