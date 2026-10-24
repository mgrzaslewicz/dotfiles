-- Git client (IntelliJ Commit / Git tool windows): Neogit, with codediff.nvim as the diff viewer
-- https://github.com/NeogitOrg/neogit
-- https://github.com/esmuellert/codediff.nvim
--
-- diffview.nvim was skipped: no commits since 2024-06; codediff is maintained and covers diffs, history and
-- 3-way conflicts. If codediff's native library fails to load, Neogit keeps working with inline diffs.
-- gitsigns (hunks, blame) stays under <leader>h; everything repository-wide is under <leader>g.
-- codediff downloads its prebuilt diff library on first use (`:CodeDiff install` to retry).
-- It is also git's merge tool (run_onchange_git_config.sh), so `git mergetool` opens the 3-way conflict view.

vim.pack.add {
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/esmuellert/codediff.nvim',
  'https://github.com/NeogitOrg/neogit',
}

-- A broken native diff library should not abort the rest of the config; Neogit works without it.
local codediff_ok, codediff_err = pcall(function() require('codediff').setup {} end)
if not codediff_ok then vim.notify('codediff.nvim disabled: ' .. codediff_err, vim.log.levels.WARN) end

local neogit = require 'neogit'
neogit.setup {
  diff_viewer = codediff_ok and 'codediff' or nil,
  integrations = { telescope = true, codediff = codediff_ok },
}

local function map(keys, func, desc, mode) vim.keymap.set(mode or 'n', keys, func, { desc = 'Git: ' .. desc }) end

map('<leader>gg', function() neogit.open() end, 'Status (stage, commit, push)')
map('<leader>gc', function() neogit.open { 'commit' } end, '[C]ommit')
map('<leader>gb', function() neogit.open { 'branch' } end, '[B]ranches')
map('<leader>gl', function() neogit.open { 'log' } end, '[L]og')
-- Working tree changes vs HEAD; conflicted files open in the 3-way merge view.
map('<leader>gd', '<cmd>CodeDiff<CR>', '[D]iff changes')
map('<leader>gD', ':CodeDiff ', '[D]iff against revision…')
map('<leader>gh', '<cmd>CodeDiff history %<CR>', 'File [H]istory')
map('<leader>gh', ':CodeDiff history<CR>', 'Selection [H]istory', 'x')
map('<leader>gH', '<cmd>CodeDiff history<CR>', 'Repository [H]istory')
