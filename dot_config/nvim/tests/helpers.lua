local M = {}

local nvim_child = vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'nvim-child')

--- Child Neovim that starts like a real session: init.lua from the source tree, plugins from tests/.tests,
--- test profile on (NVIM_TEST=1). All set up by tests/run.sh.
function M.new_child()
  local child = MiniTest.new_child_neovim()
  local start = child.start
  child.start = function(args, opts) start(args, vim.tbl_extend('force', { nvim_executable = nvim_child, connection_timeout = 20000 }, opts or {})) end
  return child
end

--- Creates a temp dir tree for fixtures and returns its path. Keys are relative paths; a trailing `/` makes an
--- empty dir, anything else a file with the value as content.
---@param files table<string, string>
---@return string
function M.tree(files)
  local root = vim.fn.tempname()
  for path, content in pairs(files) do
    local full = vim.fs.joinpath(root, path)
    if vim.endswith(path, '/') then
      vim.fn.mkdir(full, 'p')
    else
      vim.fn.mkdir(vim.fs.dirname(full), 'p')
      vim.fn.writefile(vim.split(content, '\n'), full)
    end
  end
  return root
end

--- Entry point for tests/run.sh: all test files, or only `file` when given.
---@param file string
function M.run(file)
  if file == '' then return MiniTest.run() end
  MiniTest.run_file(file)
end

return M
