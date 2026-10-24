-- Java language server via nvim-jdtls instead of plain lspconfig
-- https://github.com/mfussenegger/nvim-jdtls
--
-- Adds what plain jdtls lacks: extract variable/constant/method, organize imports,
-- Lombok support and one workspace (index) dir per project. Debugging: the java-debug-adapter
-- bundle (from Mason) lets nvim-jdtls register the `java` nvim-dap adapter (custom/plugins/debug.lua).
-- jdtls itself is installed by Mason (see `ensure_installed` in init.lua) and is on PATH.
-- The client is still named `jdtls`, which neotest-java relies on to find it.
--
-- Known limit: jdtls has no Kotlin support. In mixed Java/Kotlin projects, Java code using Kotlin classes shows
-- "cannot be resolved" errors and has no navigation, although the build compiles; Kotlin files get kotlin_lsp,
-- which does resolve Java classes (tests/e2e/test_*_mixed.lua).

vim.pack.add { 'https://github.com/mfussenegger/nvim-jdtls' }

local function start()
  local jdtls = require 'jdtls'
  -- The whole build, so a module sees its siblings (custom/jvm/project.lua); outside a build, the git repository.
  local build = require('custom.jvm.project').root(vim.fs.dirname(vim.api.nvim_buf_get_name(0)))
  local root_dir = build and build.root or vim.fs.root(0, '.git')
  if not root_dir then return end

  -- Keep each project's index separate, keyed by its full path to avoid name clashes.
  local workspace_dir = vim.fs.joinpath(vim.fn.stdpath 'cache', 'jdtls', (root_dir:gsub('[/\\:]', '_')))

  local cmd = { 'jdtls', '-data', workspace_dir }
  local lombok = vim.fs.joinpath(vim.env.MASON or '', 'share', 'jdtls', 'lombok.jar')
  if vim.uv.fs_stat(lombok) then table.insert(cmd, 2, '--jvm-arg=-javaagent:' .. lombok) end

  local bundles = {}
  local java_debug = vim.fs.joinpath(vim.env.MASON or '', 'share', 'java-debug-adapter', 'com.microsoft.java.debug.plugin.jar')
  if vim.uv.fs_stat(java_debug) then table.insert(bundles, java_debug) end

  jdtls.start_or_attach({
    cmd = cmd,
    root_dir = root_dir,
    -- vim.lsp.start (used here) does not merge `vim.lsp.config('*')`, so pass completion capabilities explicitly.
    capabilities = require('blink.cmp').get_lsp_capabilities(),
    init_options = {
      extendedClientCapabilities = jdtls.extendedClientCapabilities,
      bundles = bundles,
    },
  }, {
    -- Apply code changes to the running debuggee on save (IntelliJ HotSwap).
    ---@diagnostic disable-next-line: missing-fields
    dap = { hotcodereplace = 'auto' },
  })

  -- Back the shared <leader>r refactor keymaps with nvim-jdtls (custom/refactor.lua).
  require('custom.refactor').register(0, {
    organize_imports = function() jdtls.organize_imports() end,
    extract_variable = jdtls.extract_variable,
    extract_variable_all = jdtls.extract_variable_all,
    extract_constant = jdtls.extract_constant,
    extract_method = jdtls.extract_method,
  })
end

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('custom-jdtls', { clear = true }),
  pattern = 'java',
  callback = start,
})
