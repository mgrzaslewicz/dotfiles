-- Copy of mason-registry's packages/kotlin-lsp/package.yaml with download-cdn.jetbrains.com replaced by
-- download.jetbrains.com (the CDN host now 404s without a signed URL; download.jetbrains.com redirects to one).
-- Upstream issue: https://github.com/mason-org/mason-registry/issues/17523
-- The version comes from the pin in lua/custom/tools.lua.

local url =
  'https://download.jetbrains.com/language-server/kotlin-server/{{ version | strip_prefix "kotlin-lsp/v" }}/kotlin-server-{{ version | strip_prefix "kotlin-lsp/v" }}'
local unix_bin = 'kotlin-server-{{ version | strip_prefix "kotlin-lsp/v" }}/bin/intellij-server'

return {
  schema = 'registry+v1',
  name = 'kotlin-lsp',
  description = 'Kotlin Language Server and plugin for Visual Studio Code',
  homepage = 'https://github.com/Kotlin/kotlin-lsp',
  licenses = { 'Apache-2.0' },
  languages = { 'Kotlin' },
  categories = { 'LSP' },
  source = {
    id = 'pkg:generic/Kotlin/kotlin-lsp@' .. require('custom.tools').version 'kotlin-lsp',
    download = {
      { target = 'darwin_x64', files = { ['kotlin-lsp.zip'] = url .. '.sit' }, bin = unix_bin },
      { target = 'darwin_arm64', files = { ['kotlin-lsp.zip'] = url .. '-aarch64.sit' }, bin = unix_bin },
      { target = 'linux_x64', files = { ['kotlin-lsp.tar.gz'] = url .. '.tar.gz' }, bin = unix_bin },
      { target = 'linux_arm64', files = { ['kotlin-lsp.tar.gz'] = url .. '-aarch64.tar.gz' }, bin = unix_bin },
      { target = 'win_x64', files = { ['kotlin-lsp.zip'] = url .. '.win.zip' }, bin = 'bin/intellij-server.exe' },
      { target = 'win_arm64', files = { ['kotlin-lsp.zip'] = url .. '-aarch64.win.zip' }, bin = 'bin/intellij-server.exe' },
    },
  },
  bin = {
    ['intellij-server'] = '{{source.download.bin}}',
  },
  neovim = {
    lspconfig = 'kotlin_lsp',
  },
}
