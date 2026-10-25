-- Helpers for layer B (tests/e2e): fixture copies, condition waits with named timeouts, a diagnostics dump on
-- failure. Started by `tests/run.sh --e2e`, which sets up the e2e state dir, Gradle/Maven caches and installs.
local M = {}

local factor = tonumber(vim.env.E2E_TIMEOUT_FACTOR) or 1

-- Milliseconds per kind of wait; scale all of them with E2E_TIMEOUT_FACTOR on slow machines.
M.timeouts = {
  attach = 30000, -- server process started and initialized
  index = 180000, -- project import and first build (jdtls, kotlin-lsp)
  build = 120000, -- a Gradle/Maven task
  dap = 60000, -- debug session events
  edit = 30000, -- a refactoring from a ready server
}

local fixtures = vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'e2e', 'fixtures')

--- Copy of a fixture project in a fresh temp dir; tests build and edit only the copy.
---@param name string directory under tests/e2e/fixtures
---@return string path of the copy
function M.copy_fixture(name)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  local result = vim.system({ 'cp', '-R', vim.fs.joinpath(fixtures, name), dir }):wait()
  assert(result.code == 0, result.stderr)
  return vim.fs.joinpath(dir, name)
end

--- What the child knows that helps explain a failed wait.
function M.dump(child)
  return child.lua [[
    local lines = { '--- LSP clients' }
    for _, c in ipairs(vim.lsp.get_clients()) do
      table.insert(lines, ('%s (id %d) root %s, buffers %s'):format(c.name, c.id, c.root_dir, vim.inspect(vim.tbl_keys(c.attached_buffers))))
      local caps = c.server_capabilities or {}
      table.insert(lines, ('  diagnosticProvider %s, textDocumentSync %s'):format(vim.inspect(caps.diagnosticProvider), vim.inspect(caps.textDocumentSync)))
    end
    table.insert(lines, '--- e2e state')
    table.insert(lines, vim.inspect(_G.e2e))
    table.insert(lines, ('--- diagnostics in current buffer: %d'):format(#vim.diagnostic.get(0)))
    table.insert(lines, '--- :messages')
    table.insert(lines, vim.api.nvim_exec2('messages', { output = true }).output)
    table.insert(lines, '--- LSP log (tail)')
    local log = vim.fn.readfile(vim.lsp.log.get_filename())
    vim.list_extend(lines, vim.list_slice(log, math.max(1, #log - 40)))
    return table.concat(lines, '\n')
  ]]
end

--- Waits until `condition` (a Lua expression evaluated in the child) is truthy, or fails the test with what was
--- awaited and a dump of the child's state. The runner owns the deadline and polls: a condition must be cheap and
--- never block (start LSP requests asynchronously and poll their result), so a stuck server cannot hang the run.
---@param kind 'attach'|'index'|'build'|'dap'|'edit'
---@param what string shown on timeout
---@param condition string
function M.wait(child, kind, what, condition)
  local ms = M.timeouts[kind] * factor
  local deadline = vim.uv.hrtime() + ms * 1e6
  repeat
    if child.lua(('return (%s) and true or false'):format(condition)) then return end
    vim.wait(250)
  until vim.uv.hrtime() > deadline
  error(('timed out after %d s (%s) waiting for: %s\n%s'):format(ms / 1000, kind, what, M.dump(child)), 0)
end

--- Records jdtls `language/status` messages in the child's `_G.e2e.jdtls_status` (last type, e.g. `ServiceReady`).
--- nvim-jdtls takes the handler from the client config, so the hook goes into `start_or_attach`.
function M.record_jdtls_status(child)
  child.lua [[
    _G.e2e = _G.e2e or {}
    local jdtls = require 'jdtls'
    local start = jdtls.start_or_attach
    jdtls.start_or_attach = function(config, ...)
      config.handlers = config.handlers or {}
      config.handlers['language/status'] = function(_, result) _G.e2e.jdtls_status = result.type end
      return start(config, ...)
    end
  ]]
end

--- MiniTest set for one fixture: the fixture is copied and one child started for the whole file; each case starts
--- from no buffers. `ctx.child`, and `ctx.project` (the copy) once the set runs.
---@param fixture string
function M.fixture_set(fixture)
  local ctx = { child = require('tests.helpers').new_child() }
  local child = ctx.child
  local T = MiniTest.new_set {
    hooks = {
      pre_once = function()
        ctx.project = M.copy_fixture(fixture)
        child.start()
        child.cmd('cd ' .. ctx.project)
        M.record_jdtls_status(child)
      end,
      -- bdelete, not bwipeout: neotest's diagnostics and nvim-jdtls keep buffer ids and fail on wiped buffers.
      post_case = function() child.cmd 'silent! %bdelete!' end,
      post_once = function()
        -- jdtls keeps one workspace per root (custom/plugins/jdtls.lua); each copy is a new root.
        local workspace = vim.fs.joinpath(child.lua_get "vim.fn.stdpath 'cache'", 'jdtls', (ctx.project:gsub('[/\\:]', '_')))
        child.stop()
        vim.fn.delete(workspace, 'rf')
      end,
    },
  }
  return T, ctx
end

--- Names of the LSP clients attached to the current buffer, sorted.
function M.clients(child) return child.lua 'local n = vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients { bufnr = 0 }) table.sort(n) return n' end

--- Row 1: jdtls attaches to the current buffer with `root` as root and reports ServiceReady.
function M.expect_jdtls(child, root)
  M.wait(child, 'attach', 'jdtls attached', "#vim.lsp.get_clients { bufnr = 0, name = 'jdtls' } > 0")
  MiniTest.expect.equality(child.lua_get "vim.lsp.get_clients({ bufnr = 0, name = 'jdtls' })[1].root_dir", root)
  M.wait(child, 'index', 'jdtls ServiceReady', "_G.e2e.jdtls_status == 'ServiceReady'")
end

--- Row 2: kotlin-lsp attaches to the current buffer with `root` as root.
function M.expect_kotlin_lsp(child, root)
  M.wait(child, 'attach', 'kotlin_lsp attached', "#vim.lsp.get_clients { bufnr = 0, name = 'kotlin_lsp' } > 0")
  MiniTest.expect.equality(child.lua_get "vim.lsp.get_clients({ bufnr = 0, name = 'kotlin_lsp' })[1].root_dir", root)
end

--- Waits until go-to-definition on the first `symbol` in the current buffer leads to a file ending in `target`.
--- Proves the server has indexed the project (and, e.g., that Lombok-generated members resolve). One request at a
--- time, sent asynchronously; a request without an answer for 10 s is abandoned and sent again.
function M.definition_reaches(child, symbol, target)
  child.lua(
    [[
    _G.e2e = _G.e2e or {}
    local symbol, target = ...
    local state = { sent = nil, matched = false, answers = 0 }
    _G.e2e.definition = state
    _G.e2e.definition_poll = function()
      if state.matched then return true end
      if state.sent and vim.uv.now() - state.sent < 10000 then return false end
      local pos = vim.fn.searchpos('\\<' .. symbol .. '\\>', 'nw')
      if pos[1] == 0 then error(symbol .. ' not in buffer') end
      local params = { textDocument = vim.lsp.util.make_text_document_params(0), position = { line = pos[1] - 1, character = pos[2] - 1 } }
      state.sent = vim.uv.now()
      vim.lsp.buf_request_all(0, 'textDocument/definition', params, function(results)
        state.sent, state.answers = nil, state.answers + 1
        for _, r in pairs(results) do
          local result = r.result or {}
          for _, loc in ipairs(vim.islist(result) and result or { result }) do
            if vim.endswith(vim.uri_to_fname(loc.uri or loc.targetUri or 'file:///'), target) then state.matched = true end
          end
        end
      end)
      return false
    end
  ]],
    { symbol, target }
  )
  M.wait(child, 'index', ('definition of %s in %s'):format(symbol, target), '_G.e2e.definition_poll()')
end

--- Waits for the current buffer's deliberate warning (each fixture source has one), which proves its diagnostics
--- have arrived, then returns the error messages. While there are errors, pulls diagnostics again a few times,
--- 5 s apart: kotlin-lsp answers a pull before it has indexed the project (stale "Unresolved reference" errors).
---@return string[]
function M.errors(child)
  child.lua [[
    _G.e2e = _G.e2e or {}
    local state = { pulls = 0, last = 0 }
    _G.e2e.errors_poll = function()
      local severity = vim.diagnostic.severity
      if #vim.diagnostic.get(0, { severity = severity.WARN }) == 0 then return false end
      if #vim.diagnostic.get(0, { severity = severity.ERROR }) == 0 or state.pulls == 3 then return true end
      if vim.uv.now() - state.last > 5000 then
        state.pulls, state.last = state.pulls + 1, vim.uv.now()
        vim.lsp.diagnostic._refresh(0)
      end
      return false
    end
  ]]
  M.wait(child, 'index', 'a warning in the current buffer, and errors that stay', '_G.e2e.errors_poll()')
  return child.lua_get 'vim.tbl_map(function(d) return d.message end, vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR }))'
end

--- Row 4: writes `lines` as `path` (relative to the project copy), runs the build task named `task` the way
--- `<leader>bc` does (the picker answered with `task`), waits for it to finish and returns the quickfix list as
--- `{ file, lnum, type }` with files relative to the project and types upper case (kotlinc's `e:` gives `e`, which
--- quickfix shows as an error too); then deletes the file and the task.
---@param lines string[]
---@return { file: string, lnum: integer, type: string }[]
function M.compile_errors(child, project, path, lines, task)
  local file = vim.fs.joinpath(project, path)
  vim.fn.writefile(lines, file)
  child.lua(
    [[
    local task = ...
    vim.ui.select = function(items, opts, on_choice)
      for _, item in ipairs(items) do
        if item.name == task then return on_choice(item) end
      end
      error(task .. ' not offered: ' .. vim.inspect(vim.tbl_map(function(i) return i.name end, items)))
    end
  ]],
    { task }
  )
  child.type_keys ' bc'
  M.wait(
    child,
    'build',
    task .. ' finished',
    ("vim.iter(require('overseer').list_tasks()):any(function(t) return t.name == %q and t:is_complete() end)"):format(task)
  )
  local items = child.lua(
    [[
    local project = ...
    return vim.tbl_map(function(i)
      local name = vim.fn.fnamemodify(vim.fn.bufname(i.bufnr), ':p')
      return { file = vim.fs.relpath(project, name) or name, lnum = i.lnum, type = i.type:upper() }
    end, vim.fn.getqflist())
  ]],
    { project }
  )
  child.lua "for _, t in ipairs(require('overseer').list_tasks()) do t:dispose(true) end"
  vim.fn.delete(file)
  return items
end

--- Row 5: runs the current file's tests with `<leader>uf`, or `keys` (which also starts neotest: it discovers lazily), waits
--- until every test listed for the buffer has a result, and returns
--- `{ tests = { [adapter] = { test names } }, results = { [test name] = status } }`: adapter names without the
--- root, statuses as the gutter signs show them (`passed`, `failed`, `skipped`).
---@param keys? string default `' uf'`
function M.neotest_run_file(child, keys)
  child.type_keys(keys or ' uf')
  local done = [[(function()
    local neotest, buf, total, finished, running = require 'neotest', vim.api.nvim_get_current_buf(), 0, 0, 0
    for _, id in ipairs(neotest.state.adapter_ids()) do
      local c = neotest.state.status_counts(id, { buffer = buf })
      if c then
        total, finished, running = total + c.total, finished + c.passed + c.failed + c.skipped, running + c.running
      end
    end
    return total > 0 and running == 0 and finished == total
  end)()]]
  M.wait(child, 'build', 'neotest results for every test in the current buffer', done)
  return child.lua [[
    local neotest, buf = require 'neotest', vim.api.nvim_get_current_buf()
    local ret, signs = { tests = {}, results = {} }, {}
    for _, sign in ipairs(vim.fn.sign_getplaced(buf, { group = 'neotest-status' })[1].signs) do
      signs[sign.lnum] = sign.name:gsub('^neotest_', '')
    end
    for _, id in ipairs(neotest.state.adapter_ids()) do
      local tree = neotest.state.positions(id, { buffer = buf })
      for _, pos in tree and tree:iter() or function() end do
        if pos.type == 'test' then
          local adapter = id:match '^[^:]+'
          ret.tests[adapter] = ret.tests[adapter] or {}
          table.insert(ret.tests[adapter], pos.name)
          ret.results[pos.name] = signs[pos.range[1] + 1] or 'no sign'
        end
      end
    end
    return ret
  ]]
end

--- Row 3: puts the cursor on the first `text` in the current buffer, or selects it in visual mode, presses `keys`
--- and answers a picker (vim.ui.select) with the item shown as `pick`. Waits until the buffer changes, and returns
--- its lines from the first line containing `from`.
---@param opts { text: string, visual?: boolean, keys: string, pick?: string, from: string }
---@return string[]
function M.refactor(child, opts)
  child.lua(
    [[
    local opts = ...
    _G.e2e = _G.e2e or {}
    _G.e2e.tick = vim.b.changedtick
    vim.ui.select = function(items, select_opts, on_choice)
      for _, item in ipairs(items) do
        if (select_opts.format_item or tostring)(item) == opts.pick then return on_choice(item) end
      end
      error('picker without ' .. tostring(opts.pick) .. ': ' .. vim.inspect(vim.tbl_map(select_opts.format_item or tostring, items)))
    end
    for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      local col = line:find(opts.text, 1, true)
      if col then
        vim.api.nvim_win_set_cursor(0, { i, col - 1 })
        if opts.visual then
          vim.cmd 'normal! v'
          vim.api.nvim_win_set_cursor(0, { i, col + #opts.text - 2 })
        end
        return
      end
    end
    error(opts.text .. ' not in buffer')
  ]],
    { opts }
  )
  child.type_keys(opts.keys)
  M.wait(child, 'edit', opts.keys .. ' changed the buffer', 'vim.b.changedtick ~= _G.e2e.tick')
  return child.lua(
    [[
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i, line in ipairs(lines) do
      if line:find(..., 1, true) then return vim.list_slice(lines, i) end
    end
    return lines
  ]],
    { opts.from }
  )
end

--- Rows 6/7: sets a breakpoint with `<leader>db` on the first line containing `at` (in `file` if given, else the
--- current buffer), then from the current buffer presses `keys`, answers a picker with the first item matching the
--- Lua pattern `pick` and a `vim.fn.input` prompt with its default. Waits until the debuggee stops and returns
--- where: `{ file, line }`, file relative to `project`. The debuggee's output is collected for `debug_to_end`.
---@param opts { at: string, file?: string, keys: string, pick?: string }
---@return { file: string, line: integer }
function M.debug_until_stopped(child, project, opts)
  local launch_from = child.lua_get 'vim.api.nvim_buf_get_name(0)'
  if opts.file then child.cmd('edit ' .. opts.file) end
  child.lua(
    [[
    local opts = ...
    _G.e2e = _G.e2e or {}
    _G.e2e.dap_output = {}
    require('dap').listeners.after.event_output['e2e'] = function(_, body)
      if body.category ~= 'console' then table.insert(_G.e2e.dap_output, body.output) end
    end
    vim.fn.input = function(_, default) return default end
    vim.ui.select = function(items, select_opts, on_choice)
      local labels = vim.tbl_map(select_opts.format_item or tostring, items)
      for i, label in ipairs(labels) do
        if opts.pick and label:find(opts.pick) then return on_choice(items[i]) end
      end
      error('picker without ' .. tostring(opts.pick) .. ': ' .. vim.inspect(labels))
    end
    local line = vim.fn.search(vim.fn.escape(opts.at, '\\'), 'nw')
    if line == 0 then error(opts.at .. ' not in buffer') end
    vim.api.nvim_win_set_cursor(0, { line, 0 })
  ]],
    { opts }
  )
  child.type_keys ' db'
  child.cmd('edit ' .. launch_from)
  child.type_keys(opts.keys)
  M.wait(child, 'dap', 'debuggee stopped at a breakpoint', "require('dap').session() and require('dap').session().current_frame ~= nil")
  local frame =
    child.lua_get "(function() local f = require('dap').session().current_frame return { path = f.source and f.source.path or '?', line = f.line } end)()"
  return { file = vim.fs.relpath(project, frame.path) or frame.path, line = frame.line }
end

--- Removes the breakpoints, continues until the debuggee ends and returns its output (stdout and stderr).
---@return string
function M.debug_to_end(child)
  child.lua "require('dap').clear_breakpoints() require('dap').continue()"
  M.wait(child, 'dap', 'debuggee ended', "require('dap').session() == nil")
  return table.concat(child.lua_get '_G.e2e.dap_output', '')
end

--- Ends every debug session and removes all breakpoints.
function M.debug_stop(child)
  child.lua "require('dap').terminate() require('dap').clear_breakpoints()"
  M.wait(child, 'dap', 'no debug session', "require('dap').session() == nil")
end

return M
