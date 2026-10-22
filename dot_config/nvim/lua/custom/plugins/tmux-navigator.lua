-- Seamless navigation between Neovim splits and tmux panes with Alt+arrows
-- https://github.com/christoomey/vim-tmux-navigator
--
-- Same keys as the tmux pane bindings in ~/.tmux.conf; tmux forwards them to Neovim when it is
-- the active pane, and the plugin hands focus back to tmux at the edge of the Neovim layout.

-- Use our own keys instead of the plugin's default <C-h/j/k/l> (those stay as plain window moves).
vim.g.tmux_navigator_no_mappings = 1

vim.pack.add { 'https://github.com/christoomey/vim-tmux-navigator' }

local function map(keys, cmd, desc) vim.keymap.set('n', keys, cmd, { desc = 'Move focus to the ' .. desc .. ' window/tmux pane' }) end

map('<M-Left>', '<cmd>TmuxNavigateLeft<CR>', 'left')
map('<M-Right>', '<cmd>TmuxNavigateRight<CR>', 'right')
map('<M-Up>', '<cmd>TmuxNavigateUp<CR>', 'upper')
map('<M-Down>', '<cmd>TmuxNavigateDown<CR>', 'lower')
