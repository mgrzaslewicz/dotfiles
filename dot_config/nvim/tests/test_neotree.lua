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

-- `w` on a file asks for a window (nvim-window-picker) and opens the file there. The tree window never counts.
T['w opens the file in the only other window without asking'] = function()
  local root = helpers.tree { ['a.txt'] = 'x' }
  child.start()
  child.cmd('cd ' .. root)
  child.cmd 'Neotree show'
  child.cmd 'Neotree focus'
  child.lua [=[
    vim.wait(5000, function() return vim.bo.filetype == 'neo-tree' end)
    for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if l:match '(%S+)$' == 'a.txt' then vim.api.nvim_win_set_cursor(0, { i, 0 }) end
    end
  ]=]
  child.type_keys 'w'
  child.lua [=[ vim.wait(5000, function() return vim.api.nvim_buf_get_name(0):match 'a%.txt$' ~= nil end) ]=]

  eq(child.lua_get [=[ vim.api.nvim_buf_get_name(0):match 'a%.txt$' ~= nil ]=], true)
  eq(child.lua_get [=[ vim.bo.filetype ]=] ~= 'neo-tree', true)
end

T['w with several windows prompts, and the file opens in the picked one'] = function()
  local root = helpers.tree { ['a.txt'] = 'x' }
  child.start()
  child.cmd('cd ' .. root)
  child.cmd 'Neotree show'
  child.cmd 'vsplit'
  child.cmd 'Neotree focus'
  child.lua [=[
    vim.wait(5000, function() return vim.bo.filetype == 'neo-tree' end)
    for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if l:match '(%S+)$' == 'a.txt' then vim.api.nvim_win_set_cursor(0, { i, 0 }) end
    end
  ]=]
  child.type_keys 'w'
  child.type_keys 'F'
  child.lua [=[ vim.wait(5000, function() return vim.iter(vim.api.nvim_list_wins()):any(function(w) return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):match 'a%.txt$' ~= nil end) end) ]=]

  local opened =
    child.lua_get [=[ vim.iter(vim.api.nvim_list_wins()):filter(function(w) return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):match 'a%.txt$' ~= nil end):totable() ]=]
  eq(#opened, 1)
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

-- With no node under the cursor, Z does nothing: neo-tree would otherwise expand every root node. The command is
-- called directly with a tree that has no node, and the expansion is counted.
T['Z with no node under the cursor expands nothing'] = function()
  local root = helpers.tree { ['a/b/c/deep.txt'] = 'x' }
  child.start()
  child.cmd('cd ' .. root)
  child.cmd 'Neotree show'
  local expansions = child.lua_get [=[(function()
    local fs = require 'neo-tree.sources.filesystem.commands'
    local calls = 0
    fs.expand_all_subnodes = function() calls = calls + 1 end
    local state = require('neo-tree.sources.manager').get_state 'filesystem'
    state.tree = { get_node = function() return nil end }
    state.commands.toggle_all_subnodes(state)
    return calls
  end)()]=]
  eq(expansions, 0)
end

T['<leader>eg opens the git status tree'] = function()
  local root = helpers.tree { ['new.txt'] = 'x' }
  vim.system({ 'git', 'init', '-q' }, { cwd = root }):wait()
  child.start()
  child.cmd('cd ' .. root)
  child.type_keys(' ', 'e', 'g')
  child.lua [=[
    vim.wait(5000, function()
      local state = require('neo-tree.sources.manager').get_state 'git_status'
      return state and state.winid and vim.api.nvim_win_is_valid(state.winid)
    end)
  ]=]

  local after = child.lua_get [=[ table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n') ]=]
  eq(after:find('new.txt', 1, true) ~= nil, true)
end

return T
