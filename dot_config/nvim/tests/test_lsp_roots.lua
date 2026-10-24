-- Root dirs of the JVM language servers: the whole build (custom/jvm/project.lua), so modules see each other.
-- The e2e tests check the same on real servers; these run without them.
local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set {
  hooks = {
    pre_case = function() child.start() end,
    post_case = function() child.stop() end,
  },
}

local maven = { ['pom.xml'] = '', ['app/pom.xml'] = '', ['app/src/main/java/Main.java'] = 'class Main {}', ['app/src/main/kotlin/Main.kt'] = '' }

-- Root dir nvim-jdtls is started with for `file`; start_or_attach is replaced, so no server runs.
local function jdtls_root(file)
  return child.lua(
    [[
    local root
    require('jdtls').start_or_attach = function(config) root = config.root_dir end
    vim.cmd.edit(...)
    return root
  ]],
    { file }
  )
end

-- Root dir the kotlin_lsp config picks for `file`, without loading the buffer (which would start the server).
local function kotlin_lsp_root(file)
  return child.lua(
    [[
    local root
    vim.lsp.config.kotlin_lsp.root_dir(vim.fn.bufadd(...), function(dir) root = dir end)
    return root
  ]],
    { file }
  )
end

T['jdtls is rooted at the top of a Maven multi-module build'] = function()
  local dir = helpers.tree(maven)
  eq(jdtls_root(dir .. '/app/src/main/java/Main.java'), dir)
end

T['jdtls falls back to the git repository outside a build'] = function()
  local dir = helpers.tree { ['.git/'] = '', ['src/Main.java'] = 'class Main {}' }
  eq(jdtls_root(dir .. '/src/Main.java'), dir)
end

T['kotlin_lsp is rooted at the top of a Maven multi-module build'] = function()
  local dir = helpers.tree(maven)
  eq(kotlin_lsp_root(dir .. '/app/src/main/kotlin/Main.kt'), dir)
end

T['kotlin_lsp is rooted at the Gradle build root from a subproject'] = function()
  local dir = helpers.tree { ['settings.gradle.kts'] = '', ['app/build.gradle.kts'] = '', ['app/src/Main.kt'] = '' }
  eq(kotlin_lsp_root(dir .. '/app/src/Main.kt'), dir)
end

return T
