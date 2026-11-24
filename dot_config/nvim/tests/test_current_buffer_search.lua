-- `<leader>/`: fuzzy search in the current buffer. Its dropdown used to be capped at 80 columns, so on a wide window the
-- prompt and results stayed narrow. The dialog now takes 80% of the window width, at any size.
local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()
local T = MiniTest.new_set { hooks = { post_case = function() child.stop() end } }

T['width: 80% of the window, capped at 200 columns'] = function()
  local search = require 'custom.current_buffer_search'
  eq(search.width(120), 96)
  eq(search.width(200), 160)
  eq(search.width(400), 200)
end

T['<leader>/ opens the dialog at 80% of a wide window'] = function()
  local file = helpers.tree { ['Foo.kt'] = 'fun main() {}\nval needle = 1\n' }
  child.start()
  child.lua(([[vim.o.columns = 200; vim.cmd('edit %s')]]):format(file .. '/Foo.kt'))
  child.type_keys '<Space>/'
  child.lua [=[
    vim.wait(5000, function()
      local picker = require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
      return picker ~= nil and picker.layout ~= nil
    end, 20)
  ]=]
  local width = child.lua_get [=[
    (function()
      local picker = require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
      return picker and vim.api.nvim_win_get_width(picker.layout.results.winid)
    end)()
  ]=]
  -- The results window is the dialog minus its two border columns: 80% of 200 is 160, so 158 inside.
  eq(width, 158)
end

return T
