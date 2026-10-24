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
    end
    table.insert(lines, '--- e2e state')
    table.insert(lines, vim.inspect(_G.e2e))
    table.insert(lines, '--- :messages')
    table.insert(lines, vim.api.nvim_exec2('messages', { output = true }).output)
    table.insert(lines, '--- LSP log (tail)')
    local log = vim.fn.readfile(vim.lsp.log.get_filename())
    vim.list_extend(lines, vim.list_slice(log, math.max(1, #log - 40)))
    return table.concat(lines, '\n')
  ]]
end

--- Waits in the child until `condition` (a Lua expression evaluated there) is truthy, or fails the test with
--- what was awaited and a dump of the child's state.
---@param kind 'attach'|'index'|'build'|'dap'
---@param what string shown on timeout
---@param condition string
function M.wait(child, kind, what, condition)
  local ms = M.timeouts[kind] * factor
  local ok = child.lua(('return vim.wait(%d, function() return %s end, 200)'):format(ms, condition))
  if not ok then error(('timed out after %d s (%s) waiting for: %s\n%s'):format(ms / 1000, kind, what, M.dump(child)), 0) end
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

return M
