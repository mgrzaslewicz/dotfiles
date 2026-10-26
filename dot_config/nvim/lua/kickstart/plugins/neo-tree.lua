-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

vim.pack.add {
  { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
}

vim.keymap.set('n', '\\', '<Cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })
vim.keymap.set('n', '<leader>en', '<Cmd>Neotree reveal<CR>', { desc = 'Explorer: reveal current file', silent = true })
vim.keymap.set('n', '<leader>ee', '<Cmd>Neotree toggle<CR>', { desc = 'Explorer: toggle tree', silent = true })
vim.keymap.set('n', '<leader>ef', '<Cmd>Neotree focus<CR>', { desc = 'Explorer: focus tree', silent = true })

-- Z: expand the selected directory recursively, or collapse it again when it is already expanded.
local common = require 'neo-tree.sources.common.commands'
local filesystem = require 'neo-tree.sources.filesystem.commands'
local manager = require 'neo-tree.sources.manager'

-- Runs fn on the open filesystem tree's state; does nothing when the tree is closed.
local function with_open_tree(fn)
  local state = manager.get_state 'filesystem'
  if state and state.tree and state.winid and vim.api.nvim_win_is_valid(state.winid) then fn(state) end
end

vim.keymap.set('n', '<leader>eh', function() with_open_tree(filesystem.toggle_hidden) end, { desc = 'Explorer: toggle hidden files', silent = true })
vim.keymap.set('n', '<leader>ec', function() with_open_tree(common.close_all_nodes) end, { desc = 'Explorer: collapse all', silent = true })

-- Autoscroll: reveal the file of each buffer entered while the tree is open. Neo-tree's own follow option cannot be
-- switched at runtime, so this uses a flag checked on every BufEnter.
vim.g.explorer_autoscroll = true
vim.api.nvim_create_autocmd('BufEnter', {
  callback = function(args)
    if vim.g.explorer_autoscroll and vim.bo[args.buf].buftype == '' and vim.api.nvim_buf_get_name(args.buf) ~= '' then
      with_open_tree(function() filesystem.follow() end)
    end
  end,
})
vim.keymap.set('n', '<leader>es', function()
  vim.g.explorer_autoscroll = not vim.g.explorer_autoscroll
  vim.notify('Explorer autoscroll ' .. (vim.g.explorer_autoscroll and 'on' or 'off'))
  if vim.g.explorer_autoscroll then with_open_tree(function() filesystem.follow() end) end
end, { desc = 'Explorer: toggle autoscroll', silent = true })

require('neo-tree').setup {
  filesystem = {
    window = {
      mappings = {
        ['\\'] = 'close_window',
        ['Z'] = 'toggle_all_subnodes',
      },
    },
    commands = {
      toggle_all_subnodes = function(state)
        local node = state.tree:get_node()
        if node and node.type == 'directory' and node:is_expanded() then
          common.close_all_subnodes(state)
        else
          filesystem.expand_all_subnodes(state, node)
        end
      end,
    },
  },
}
