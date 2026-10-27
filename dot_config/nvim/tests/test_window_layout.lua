-- Window layout: when the terminal (or tmux window) is resized, splits are equalized, as `<C-w>=` would do. Without
-- it Neovim keeps each split's size and hands the difference to the last window, so the layout loses its proportions.
local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()
local T = MiniTest.new_set { hooks = { post_case = function() child.stop() end } }

T['VimResized equalizes splits'] = function()
  child.start()
  child.lua [=[
    vim.cmd 'vsplit'
    vim.cmd 'vsplit'
    vim.api.nvim_win_set_width(0, 10)
    vim.api.nvim_exec_autocmds('VimResized', {})
  ]=]

  local widths = child.lua_get [=[
    (function()
      local w = {}
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do table.insert(w, vim.api.nvim_win_get_width(win)) end
      return w
    end)()
  ]=]
  eq(widths[1], widths[2])
  eq(widths[2], widths[3])
end

return T
