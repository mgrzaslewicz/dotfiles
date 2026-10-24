local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

-- Mason has no lockfile: every package is installed at the version pinned in custom/tools.lua, bumped on purpose
-- and checked with `mise run test:e2e`.
T['every Mason package is pinned'] = function()
  local unpinned = {}
  for _, tool in ipairs(require('custom.tools').mason) do
    if type(tool.version) ~= 'string' or tool.version == '' then table.insert(unpinned, tool[1]) end
  end
  eq(unpinned, {})
end

T['the kotlin-lsp registry override installs the pinned version'] = function()
  local spec = require 'custom.mason-registry.kotlin-lsp'
  eq(spec.source.id, 'pkg:generic/Kotlin/kotlin-lsp@' .. require('custom.tools').version 'kotlin-lsp')
end

local child = helpers.new_child()

T['every enabled LSP server with a Mason package is in the pinned list'] = function()
  child.start()
  local missing = child.lua [=[
    local pinned = {}
    for _, tool in ipairs(require('custom.tools').mason) do pinned[tool[1]] = true end
    local missing = {}
    for server, package in pairs(require('mason-lspconfig').get_mappings().lspconfig_to_package) do
      if vim.lsp.is_enabled(server) and not pinned[package] then table.insert(missing, package) end
    end
    return missing
  ]=]
  child.stop()
  eq(missing, {})
end

return T
