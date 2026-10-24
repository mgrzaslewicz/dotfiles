-- One Gradle module with Java and Kotlin calling each other (fixtures/gradle-mixed).
local e2e = require 'tests.e2e.helpers'
local eq = MiniTest.expect.equality

local T, ctx = e2e.fixture_set 'gradle-mixed'

T['gradle-mixed | LSP | Java files get jdtls only, at the build root, without errors'] = function()
  ctx.child.cmd 'edit src/main/java/com/example/mixed/JavaGreeter.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  eq(e2e.clients(ctx.child), { 'jdtls' })
  eq(e2e.errors(ctx.child), {})
end

T['gradle-mixed | LSP | Kotlin files get kotlin_lsp only, at the build root, resolving Java classes'] = function()
  ctx.child.cmd 'edit src/main/kotlin/com/example/mixed/Main.kt'
  e2e.expect_kotlin_lsp(ctx.child, ctx.project)
  eq(e2e.clients(ctx.child), { 'kotlin_lsp' })
  e2e.definition_reaches(ctx.child, 'greet', 'src/main/java/com/example/mixed/JavaGreeter.java')
  eq(e2e.errors(ctx.child), {})
end

-- Known limit: jdtls has no Kotlin support, so Java code using a Kotlin class gets an error and no navigation
-- (Gradle and Maven compile it fine). Turns red if jdtls ever resolves it. See custom/plugins/jdtls.lua.
T['gradle-mixed | LSP | known limit: jdtls reports Kotlin classes used from Java as unresolved'] = function()
  ctx.child.cmd 'edit src/main/java/com/example/mixed/Report.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  e2e.wait(
    ctx.child,
    'index',
    'jdtls error about KotlinFormatter in Report.java',
    "vim.iter(vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })):any(function(d) return d.message:find('KotlinFormatter', 1, true) end)"
  )
end

return T
