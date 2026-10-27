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

--- Attaches a fake LSP server to the child's current buffer and waits for the LspAttach keymaps. It offers the code
--- actions whose titles are in the child's `_G.offered`; each applies by running a client-side command that records
--- its title in `_G.applied`.
function M.attach_fake_lsp(child)
  child.lua [[
    _G.offered, _G.applied = {}, {}
    vim.lsp.commands['test.apply'] = function(cmd) table.insert(_G.applied, cmd.arguments[1]) end
    vim.lsp.start {
      name = 'fake',
      root_dir = vim.fn.getcwd(),
      cmd = function()
        local closing = false
        return {
          request = function(method, params, callback)
            if method == 'textDocument/codeAction' then _G.code_action_range = params.range end
            local result = ({
              initialize = { capabilities = { codeActionProvider = true, renameProvider = true, inlayHintProvider = true } },
              ['textDocument/codeAction'] = vim.tbl_map(
                function(title) return { title = title, kind = params.context and params.context.only[1], command = { title = title, command = 'test.apply', arguments = { title } } } end,
                _G.offered
              ),
            })[method]
            vim.schedule(function() callback(nil, result) end)
            return true, 1
          end,
          notify = function() return true end,
          is_closing = function() return closing end,
          terminate = function() closing = true end,
        }
      end,
    }
    vim.wait(2000, function() return vim.fn.maparg(' rn', 'n') ~= '' end)
  ]]
end

--- Creates a temp dir tree for fixtures and returns its path. Keys are relative paths; a trailing `/` makes an
--- empty dir, anything else a file with the value as content. The path is resolved (macOS: /var is /private/var),
--- since nvim reports resolved paths and tests compare against them.
---@param files table<string, string>
---@return string
function M.tree(files)
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, 'p')
  root = vim.uv.fs_realpath(root) or root
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

--- Entry point for tests/run.sh: all test files of a layer (`tests` or `tests/e2e`), or only `file` when given.
---@param dir string
---@param file string
function M.run(dir, file)
  if file ~= '' then return MiniTest.run_file(file) end
  -- Not mini.test's default: it collects `tests/**/test_*.lua`, which would mix the layers.
  MiniTest.run { collect = { find_files = function() return vim.fn.globpath(dir, 'test_*.lua', true, true) end } }
end

return M
