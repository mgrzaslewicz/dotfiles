-- Go to Class (IntelliJ Ctrl+N): workspace symbols with a fuzzy, package-aware prompt, e.g. `java.io InputStream`.
-- The picker is shared with `gW` (lua/custom/workspace_symbols.lua), which explains the query and the empty prompt.
-- jdtls returns JDK and library types only because nvim-jdtls advertises `classFileContentsSupport` (see
-- custom/plugins/jdtls.lua).

---@param opts? table telescope picker options, plus `symbols` (kinds to keep, as for builtin.lsp_*_symbols)
return function(opts)
  local workspace_symbols = require 'custom.workspace_symbols'
  workspace_symbols.picker(opts, opts and opts.prompt_title or workspace_symbols.title 'Go to Class')
end
