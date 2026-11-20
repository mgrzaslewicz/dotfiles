local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local base = { 'rg', '--color=never', '--line-number' }

local child = helpers.new_child()

local T = MiniTest.new_set { hooks = { post_case = function() child.stop() end } }

T['command: an empty glob adds no --glob, the pattern comes after --'] = function()
  local grep = require 'custom.grep'
  eq(grep.command('foo', '', base), { 'rg', '--color=never', '--line-number', '--', 'foo' })
end

T['command: a non-empty glob is passed as --glob before the separator'] = function()
  local grep = require 'custom.grep'
  eq(grep.command('foo', '*.json', base), { 'rg', '--color=never', '--line-number', '--glob', '*.json', '--', 'foo' })
end

T['command: a pattern starting with a dash is still a pattern'] = function()
  local grep = require 'custom.grep'
  eq(grep.command('-v', '', base)[#base + 2], '-v')
end

T['command: no pattern means no search'] = function()
  local grep = require 'custom.grep'
  eq(grep.command('', '*.json', base), nil)
end

T['other: the two inputs alternate'] = function()
  local grep = require 'custom.grep'
  eq(grep.other 'pattern', 'glob')
  eq(grep.other 'glob', 'pattern')
end

-- Number of results the grep picker currently shows; nil when it is not open.
local function results()
  return child.lua_get [[(function()
    local picker = require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
    return picker and picker.manager and picker.manager:num_results()
  end)()]]
end

local function wait_results(count)
  child.lua(([[vim.wait(5000, function() return (function()
    local picker = require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
    return picker and picker.manager and picker.manager:num_results() == %d
  end)() end, 20)]]):format(count))
  eq(results(), count)
end

T['<leader>sG: the glob is empty by default, Tab moves to the glob input and narrows the search by it'] = function()
  local dir = helpers.tree { ['a.json'] = 'needle', ['b.txt'] = 'needle' }
  child.start()
  child.cmd('cd ' .. dir)
  child.type_keys(' ', 's', 'G')
  child.type_keys 'needle'
  wait_results(2)

  child.type_keys '<Tab>'
  child.type_keys '*.json'
  wait_results(1)
end

T['<leader>sG: Tab back restores the pattern input, the glob stays'] = function()
  local dir = helpers.tree { ['a.json'] = 'needle', ['b.txt'] = 'needle' }
  child.start()
  child.cmd('cd ' .. dir)
  child.type_keys(' ', 's', 'G')
  child.type_keys 'needle'
  child.type_keys '<Tab>'
  child.type_keys '*.json'
  wait_results(1)

  child.type_keys '<Tab>'
  local line =
    child.lua_get "vim.api.nvim_buf_get_lines(require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf()).prompt_bufnr, 0, -1, false)[1]"
  eq(line:sub(-6), 'needle')
  wait_results(1)
end

return T
