-- Sessions (IntelliJ reopens a project as you left it): persistence.nvim
-- https://github.com/folke/persistence.nvim
--
-- One session per working directory (and git branch other than main/master), saved on exit to
-- stdpath('state')/sessions/. Starting `nvim` without arguments restores the session for the cwd;
-- starting it with files (or stdin) leaves the session alone and doesn't save one.

vim.pack.add { 'https://github.com/folke/persistence.nvim' }

-- Panels (neo-tree, dap-ui, neotest summary, overseer, terminals) don't restore cleanly, so they are not saved.
vim.opt.sessionoptions = { 'buffers', 'curdir', 'folds', 'tabpages', 'winsize' }

local persistence = require 'persistence'
persistence.setup {}

-- Panels left open would come back as empty windows, so close every non-file window before saving.
vim.api.nvim_create_autocmd('User', {
  pattern = 'PersistenceSavePre',
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype ~= '' and #vim.api.nvim_list_wins() > 1 then pcall(vim.api.nvim_win_close, win, true) end
    end
  end,
})

vim.api.nvim_create_autocmd('VimEnter', {
  -- nested: restored buffers must fire their BufRead/FileType autocmds (treesitter, LSP)
  nested = true,
  callback = function()
    if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
      persistence.load()
    else
      -- A quick `nvim Foo.java` must not overwrite the project's session.
      persistence.stop()
    end
  end,
})
vim.api.nvim_create_autocmd('StdinReadPre', { callback = function() vim.g.started_with_stdin = true end })

local function map(keys, func, desc) vim.keymap.set('n', keys, func, { desc = 'Session: ' .. desc }) end

-- Restoring by hand also resumes saving, in case nvim was started with files.
map('<leader>wr', function()
  persistence.start()
  persistence.load()
end, '[R]estore for cwd')
map('<leader>ws', function()
  persistence.start()
  persistence.select()
end, '[S]elect project…')
map('<leader>wl', function()
  persistence.start()
  persistence.load { last = true }
end, 'Restore [L]ast')
map('<leader>wd', function() persistence.stop() end, "[D]on't save on exit")
