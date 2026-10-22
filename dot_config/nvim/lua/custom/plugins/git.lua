-- Git client (IntelliJ Commit / Git tool windows): Neogit, with codediff.nvim as the diff viewer
-- https://github.com/NeogitOrg/neogit
-- https://github.com/esmuellert/codediff.nvim
--
-- gitsigns (hunks, blame) stays under <leader>h; everything repository-wide is under <leader>g.
-- codediff downloads its prebuilt diff library on first use (`:CodeDiff install` to retry).
-- It is also git's merge tool (run_onchange_git_config.sh), so `git mergetool` opens the 3-way conflict view.

vim.pack.add {
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/esmuellert/codediff.nvim',
  'https://github.com/NeogitOrg/neogit',
}

-- Snap-packaged nvim runs against Ubuntu core22's glibc, but the host's libgomp (which codediff's native
-- library links) needs a newer one. codediff's installer only bundles its own old-glibc libgomp for Nix,
-- so bundle it here for snap; the library finds it next to itself via RPATH $ORIGIN.
local function bundle_libgomp_for_snap()
  if not (vim.env.SNAP or vim.v.progpath:find '^/snap/') then return end
  local root = vim.pack.get({ 'codediff.nvim' })[1].path
  local libgomp = vim.fs.joinpath(root, 'libgomp.so.1')
  if vim.uv.fs_stat(libgomp) then return end

  local version = vim.trim(table.concat(vim.fn.readfile(vim.fs.joinpath(root, 'VERSION')), ''))
  local arch = ({ x86_64 = 'x64', aarch64 = 'arm64' })[vim.uv.os_uname().machine]
  if not arch then return end
  local url = ('https://github.com/esmuellert/codediff.nvim/releases/download/v%s/libgomp_linux_%s_%s.so.1'):format(version, arch, version)
  local result = vim.system({ 'curl', '-fsSL', '-o', libgomp, url }):wait()
  if result.code ~= 0 then
    os.remove(libgomp)
    vim.notify('codediff: failed to download bundled libgomp: ' .. (result.stderr or ''), vim.log.levels.WARN)
  end
end
bundle_libgomp_for_snap()

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
