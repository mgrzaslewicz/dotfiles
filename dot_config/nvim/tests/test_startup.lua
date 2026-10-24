local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set {
  hooks = {
    pre_case = function() child.start() end,
    post_case = function() child.stop() end,
  },
}

T['config loads without errors or messages'] = function()
  -- Give async startup work (installers, deferred notifications) time to report.
  child.lua 'vim.wait(1000)'
  eq(child.v.errmsg, '')
  eq(child.cmd_capture 'messages', '')
end

-- Test children share one state dir; a session saved by one would be restored by the next (layer B tests sessions).
T['test profile neither restores nor saves sessions'] = function()
  child.cmd('edit ' .. require('tests.helpers').tree { ['Leak.txt'] = '' } .. '/Leak.txt')
  child.restart()
  local listed = child.lua 'return vim.tbl_map(vim.api.nvim_buf_get_name, vim.tbl_filter(function(b) return vim.bo[b].buflisted end, vim.api.nvim_list_bufs()))'
  eq(vim.tbl_filter(function(name) return name ~= '' end, listed), {})
end

return T
