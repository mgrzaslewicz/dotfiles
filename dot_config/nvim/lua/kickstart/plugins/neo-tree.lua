-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

vim.pack.add {
  { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
}

vim.keymap.set('n', '\\', '<Cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })

-- Z: expand the selected directory recursively, or collapse it again when it is already expanded.
local common = require 'neo-tree.sources.common.commands'
local filesystem = require 'neo-tree.sources.filesystem.commands'

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
