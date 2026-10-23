local M = {}

local nvim_child = vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'nvim-child')

--- Child Neovim that starts like a real session: init.lua from the source tree, plugins from tests/.tests,
--- test profile on (NVIM_TEST=1). All set up by tests/run.sh.
function M.new_child()
  local child = MiniTest.new_child_neovim()
  local start = child.start
  child.start = function(args, opts)
    start(args, vim.tbl_extend('force', { nvim_executable = nvim_child, connection_timeout = 20000 }, opts or {}))
  end
  return child
end

--- Entry point for tests/run.sh: all test files, or only `file` when given.
---@param file string
function M.run(file)
  if file == '' then return MiniTest.run() end
  MiniTest.run_file(file)
end

return M
