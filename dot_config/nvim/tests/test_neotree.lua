-- Neo-tree: `Z` on a directory expands it recursively, so nested Java/Kotlin packages open in one key.
local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()
local T = MiniTest.new_set { hooks = { post_case = function() child.stop() end } }

T['Z expands the selected directory and all its subdirectories'] = function()
  local root = helpers.tree { ['a/b/c/deep.txt'] = 'x' }
  child.start()
  child.cmd('cd ' .. root)
  child.cmd 'Neotree show'
  child.cmd 'Neotree focus'
  child.lua [=[
    vim.wait(5000, function() return vim.bo.filetype == 'neo-tree' end)
    for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if l:match '(%S+)$' == 'a' then vim.api.nvim_win_set_cursor(0, { i, 0 }) end
    end
  ]=]
  local before = child.lua_get [=[ table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n') ]=]
  eq(before:find('deep.txt', 1, true), nil)

  child.type_keys 'Z'
  child.lua [=[ vim.wait(5000, function() return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('deep.txt', 1, true) ~= nil end) ]=]

  local after = child.lua_get [=[ table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n') ]=]
  eq(after:find('deep.txt', 1, true) ~= nil, true)
end

T['Z on an expanded directory collapses it again'] = function()
  local root = helpers.tree { ['a/b/c/deep.txt'] = 'x' }
  child.start()
  child.cmd('cd ' .. root)
  child.cmd 'Neotree show'
  child.cmd 'Neotree focus'
  child.lua [=[
    vim.wait(5000, function() return vim.bo.filetype == 'neo-tree' end)
    for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if l:match '(%S+)$' == 'a' then vim.api.nvim_win_set_cursor(0, { i, 0 }) end
    end
  ]=]
  child.type_keys 'Z'
  child.lua [=[ vim.wait(5000, function() return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('deep.txt', 1, true) ~= nil end) ]=]

  child.type_keys 'Z'
  child.lua [=[ vim.wait(5000, function() return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('deep.txt', 1, true) == nil end) ]=]

  local after = child.lua_get [=[ table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n') ]=]
  eq(after:find('deep.txt', 1, true), nil)
end

T['<leader>ec collapses every expanded node'] = function()
  local root = helpers.tree { ['a/b/c/deep.txt'] = 'x' }
  child.start()
  child.cmd('cd ' .. root)
  child.cmd 'Neotree show'
  child.cmd 'Neotree focus'
  child.lua [=[
    vim.wait(5000, function() return vim.bo.filetype == 'neo-tree' end)
    for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if l:match '(%S+)$' == 'a' then vim.api.nvim_win_set_cursor(0, { i, 0 }) end
    end
  ]=]
  child.type_keys 'Z'
  child.lua [=[ vim.wait(5000, function() return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('deep.txt', 1, true) ~= nil end) ]=]

  child.type_keys(' ', 'e', 'c')
  child.lua [=[ vim.wait(5000, function() return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('deep.txt', 1, true) == nil end) ]=]

  local after = child.lua_get [=[ table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n') ]=]
  eq(after:find('deep.txt', 1, true), nil)
end

T['<leader>es toggles autoscroll, on by default'] = function()
  child.start()
  eq(child.lua_get 'vim.g.explorer_autoscroll', true)
  child.type_keys(' ', 'e', 's')
  eq(child.lua_get 'vim.g.explorer_autoscroll', false)
  child.type_keys(' ', 'e', 's')
  eq(child.lua_get 'vim.g.explorer_autoscroll', true)
end

T['<leader>es with the tree open runs without errors'] = function()
  local root = helpers.tree { ['a/b/c/deep.txt'] = 'x' }
  child.start()
  child.cmd('cd ' .. root)
  child.cmd 'Neotree show'
  child.cmd 'Neotree focus'
  child.lua [=[ vim.wait(5000, function() return vim.bo.filetype == 'neo-tree' end) ]=]
  child.cmd 'messages clear'
  child.type_keys(' ', 'e', 's')
  child.type_keys(' ', 'e', 's')
  child.lua [=[ vim.wait(500) ]=]
  local messages = child.cmd_capture 'messages'
  eq(messages:find('attempt to call', 1, true), nil)
  eq(messages:find('E5108', 1, true), nil)
end

T['<leader>eh shows hidden files'] = function()
  local root = helpers.tree { ['.hidden.txt'] = 'x', ['visible.txt'] = 'x' }
  child.start()
  child.cmd('cd ' .. root)
  child.cmd 'Neotree show'
  child.cmd 'Neotree focus'
  child.lua [=[ vim.wait(5000, function() return vim.bo.filetype == 'neo-tree' end) ]=]
  local before = child.lua_get [=[ table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n') ]=]
  eq(before:find('.hidden.txt', 1, true), nil)

  child.type_keys(' ', 'e', 'h')
  child.lua [=[ vim.wait(5000, function() return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('.hidden.txt', 1, true) ~= nil end) ]=]

  local after = child.lua_get [=[ table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n') ]=]
  eq(after:find('.hidden.txt', 1, true) ~= nil, true)
end

return T
