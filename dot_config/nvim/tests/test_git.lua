local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set { hooks = { post_case = function() child.stop() end } }

-- The native diff library loads in codediff.core.diff (ffi.load), pulled in by setup.
T['a broken codediff native library leaves Neogit working without it'] = function()
  child.start { '--cmd', "lua package.preload['codediff.core.diff'] = function() error('libvscode_diff.so: cannot open shared object file') end" }
  eq(child.v.errmsg, '')
  eq(child.fn.exists ':Neogit', 2)
  eq(child.lua_get "require('neogit.config').values.integrations.codediff", false)
  eq(child.cmd_capture('messages'):find('codediff.nvim disabled', 1, true) ~= nil, true)
end

T['codediff is Neogit diff viewer when it loads'] = function()
  child.start()
  eq(child.lua_get "require('neogit.config').values.diff_viewer", 'codediff')
end

return T
