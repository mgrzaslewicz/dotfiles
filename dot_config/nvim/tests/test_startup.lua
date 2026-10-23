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

return T
