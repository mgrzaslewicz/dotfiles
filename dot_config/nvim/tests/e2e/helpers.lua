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
---@param kind 'attach'|'index'|'build'|'dap'
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
      post_case = function() child.cmd 'silent! %bwipeout!' end,
      post_once = function() child.stop() end,
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
--- have arrived, then returns the error messages.
---@return string[]
function M.errors(child)
  M.wait(child, 'index', 'a warning in the current buffer', '#vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN }) > 0')
  return child.lua_get 'vim.tbl_map(function(d) return d.message end, vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR }))'
end

return M
