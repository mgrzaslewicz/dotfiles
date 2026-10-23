-- Init for the test runner process only (the config under test runs in child processes, see helpers.lua).
-- Started by tests/run.sh with cwd = the config root.
vim.opt.rtp:prepend(vim.fs.joinpath(vim.fn.stdpath 'data', 'site', 'pack', 'core', 'opt', 'mini.nvim'))
package.path = './?.lua;' .. package.path

require('mini.test').setup()
