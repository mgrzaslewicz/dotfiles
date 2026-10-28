local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set {
  hooks = {
    pre_case = function() child.start() end,
    post_case = function() child.stop() end,
  },
}

-- Background colors of the highlights `highlighter` put on a file holding `text`.
local function backgrounds(text, highlighter)
  child.cmd('edit ' .. helpers.tree { ['tmux.conf'] = text } .. '/tmux.conf')
  return child.lua(
    [[
    local ns = vim.api.nvim_get_namespaces()['MiniHipatterns-' .. ...]
    vim.wait(2000, function() return ns and #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) > 0 end)
    local marks = ns and vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true }) or {}
    return vim.tbl_map(function(mark) return vim.api.nvim_get_hl(0, { name = mark[4].hl_group }).bg end, marks)
  ]],
    { highlighter }
  )
end

T['hex colors are shown in their own color'] = function() eq(backgrounds('green_soft="#A3BE8C"\n', 'hex_color'), { 0xA3BE8C }) end

T['tmux 256-color names are shown in their own color'] = function()
  eq(backgrounds("set -g window-style 'fg=colour247,bg=color232'\n", 'term_color'), { 0x9E9E9E, 0x080808 })
end

T['tmux color names beyond 255 or inside words are not highlighted'] = function() eq(backgrounds('colour256 mycolour7 colour12x\n', 'term_color'), {}) end

return T
