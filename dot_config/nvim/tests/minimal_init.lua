-- Init for the test runner process only (the config under test runs in child processes, see helpers.lua).
-- Started by tests/run.sh with cwd = the config root.
vim.opt.rtp:prepend(vim.fs.joinpath(vim.fn.stdpath 'data', 'site', 'pack', 'core', 'opt', 'mini.nvim'))
package.path = './?.lua;' .. package.path

-- An error here would leave headless nvim running forever; fail the run instead.
local ok, minitest = pcall(require, 'mini.test')
if not ok then
  io.stderr:write(('mini.test not available (delete tests/.tests to reinstall plugins):\n%s\n'):format(minitest))
  vim.cmd 'cquit 1'
end
minitest.setup()
