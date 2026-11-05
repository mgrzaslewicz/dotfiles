-- `]e` / `[e`: next / previous error, skipping warnings and hints (IntelliJ F2 / Shift+F2 with "errors first").
-- `]d` / `[d` stop on every diagnostic, the deliberate unused import included.
local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.start()
      child.lua [=[
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c', 'd', 'e', 'f' })
        local ns = vim.api.nvim_create_namespace 'test'
        local function d(lnum, severity) return { lnum = lnum, col = 0, message = 'x', severity = vim.diagnostic.severity[severity] } end
        vim.diagnostic.set(ns, 0, { d(1, 'WARN'), d(2, 'ERROR'), d(3, 'HINT'), d(4, 'ERROR') })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
      ]=]
    end,
    post_case = function() child.stop() end,
  },
}

local function press(keys, row)
  child.type_keys(keys)
  eq({ keys, child.lua_get 'vim.api.nvim_win_get_cursor(0)[1]' }, { keys, row })
end

T[']e and [e jump between errors only, wrapping around'] = function()
  press(']e', 3)
  press(']e', 5)
  press(']e', 3)
  press('[e', 5)
  press('[e', 3)
end

T[']e takes a count'] = function() press('2]e', 5) end

return T
