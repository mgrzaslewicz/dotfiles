-- External tools installed by Mason, pinned like the plugins in nvim-pack-lock.json: Mason has no lockfile, so
-- versions only change here. To update: bump a version (`:Mason` shows newer ones), run `mise run test:e2e`,
-- commit. Names are Mason package names. Tests: tests/test_tools.lua.

local M = {}

M.mason = {
  -- Java (Eclipse JDT LS), started by nvim-jdtls. Needs a Java 25+ runtime on PATH (custom/health.lua); Mason's launcher also needs python3.
  { 'jdtls', version = 'v1.63.0' },
  -- Java debugger, loaded into jdtls as a bundle by lua/custom/plugins/jdtls.lua.
  { 'java-debug-adapter', version = '0.59.0' },
  -- Kotlin, JetBrains' official server, from our registry override (lua/custom/mason-registry).
  { 'kotlin-lsp', version = 'kotlin-lsp/v263.7084.0' },
  -- Kotlin debugger, configured in lua/custom/plugins/debug.lua.
  { 'kotlin-debug-adapter', version = '0.4.4' },
  -- Python, started by enabling `pyright` in `servers` (init.lua).
  { 'pyright', version = '1.1.414' },
  { 'lua-language-server', version = '3.19.2' },
  -- Lua formatter (conform); same version as the repo's mise.toml pin used by `mise run check`.
  { 'stylua', version = 'v2.6.0' },
}

-- Treesitter parsers installed on startup (others are installed when a file type first needs one). Their revisions
-- are pinned by nvim-treesitter's own revision in nvim-pack-lock.json. neotest finds Java/Kotlin tests with them.
M.parsers = { 'bash', 'c', 'diff', 'html', 'java', 'kotlin', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }

--- Pinned version of a Mason package.
---@param name string
---@return string|nil
function M.version(name)
  for _, tool in ipairs(M.mason) do
    if tool[1] == name then return tool.version end
  end
end

return M
