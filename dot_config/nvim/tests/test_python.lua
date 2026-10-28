-- Python navigation: pyright (Mason) is enabled for Python buffers and rooted at the project, not at a package.
-- Real pyright runs in layer B only; these check the wiring without a server.
local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set {
  hooks = {
    pre_case = function() child.start() end,
    post_case = function() child.stop() end,
  },
}

local project = {
  ['pyproject.toml'] = '[project]\nname = "app"\n',
  ['app/__init__.py'] = '',
  ['app/models/user.py'] = 'class User:\n    pass\n',
}

T['pyright is enabled'] = function() eq(child.lua_get [[vim.lsp.is_enabled 'pyright']], true) end

T['pyright is rooted at the project with pyproject.toml, not at a package'] = function()
  local dir = helpers.tree(project)
  local root = child.lua(
    [[
    local file = ...
    return vim.fs.root(file, vim.lsp.config.pyright.root_markers)
  ]],
    { dir .. '/app/models/user.py' }
  )
  eq(root, dir)
end

return T
