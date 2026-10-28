-- tmux config files: Neovim's tmux syntax (runtime syntax/tmux.vim) highlights them; there is no tmux language
-- server or treesitter parser. Completion comes from that syntax's keywords (commands, options, values) through
-- `syntaxcomplete#Complete` as the omnifunc, which blink.cmp reads via its `omni` source (per_filetype in init.lua).
-- Tests: tests/test_tmux.lua.

-- chezmoi sources (dot_tmux.conf) as tmux files, like ~/.tmux.conf.
vim.filetype.add { pattern = { ['.*/dot_tmux.*%.conf'] = 'tmux' } }

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'tmux',
  group = vim.api.nvim_create_augroup('custom-tmux', { clear = true }),
  callback = function(args)
    -- Option names are hyphenated (status-left-style): complete them whole, and let `w`/`*` treat them as one word.
    vim.opt_local.iskeyword:append '-'
    vim.bo[args.buf].omnifunc = 'syntaxcomplete#Complete'
  end,
})
