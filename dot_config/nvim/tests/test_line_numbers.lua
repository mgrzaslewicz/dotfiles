local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set {
  hooks = {
    pre_case = function() child.start() end,
    post_case = function() child.stop() end,
  },
}

T['<leader>tr toggles relative numbers and keeps absolute numbers'] = function()
  eq(child.lua_get 'vim.wo.relativenumber', false)
  child.type_keys(' ', 't', 'r')
  eq(child.lua_get 'vim.wo.relativenumber', true)
  eq(child.lua_get 'vim.wo.number', true)
  child.type_keys(' ', 't', 'r')
  eq(child.lua_get 'vim.wo.relativenumber', false)
  eq(child.lua_get 'vim.wo.number', true)
end

return T
