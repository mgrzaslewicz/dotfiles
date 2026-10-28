-- tmux config files: highlighted by Neovim's tmux syntax, also as chezmoi sources (dot_tmux.conf), and completed
-- from that syntax's keywords (commands, options), since there is no tmux language server.
local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set {
  hooks = {
    pre_case = function() child.start() end,
    post_case = function() child.stop() end,
  },
}

local function edit(name, text)
  child.cmd('edit ' .. helpers.tree { [name] = text or '' } .. '/' .. name)
  return child.lua_get '{ vim.bo.filetype, vim.b.current_syntax }'
end

T['~/.tmux.conf is highlighted as tmux'] = function() eq(edit '.tmux.conf', { 'tmux', 'tmux' }) end

T['the chezmoi source dot_tmux.conf is highlighted as tmux'] = function() eq(edit 'dot_tmux.conf', { 'tmux', 'tmux' }) end

T['tmux option names are completed whole, hyphens included'] = function()
  edit('.tmux.conf', 'set -g status-s')
  child.type_keys 'A'
  local items = child.lua [[
    require('blink.cmp').show()
    local words = {}
    vim.wait(2000, function()
      for _, item in ipairs(require('blink.cmp').get_items()) do words[item.label] = true end
      return words['status-style']
    end)
    return { words['status-style'] or false, words['status-left-style'] or false }
  ]]
  eq(items, { true, false })
end

return T
