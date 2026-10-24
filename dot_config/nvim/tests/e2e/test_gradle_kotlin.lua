-- Kotlin-only multi-module Gradle build (fixtures/gradle-kotlin).
local e2e = require 'tests.e2e.helpers'
local eq = MiniTest.expect.equality

local T, ctx = e2e.fixture_set 'gradle-kotlin'

T['gradle-kotlin | LSP | kotlin_lsp attaches at the build root, resolves across modules, reports no errors'] = function()
  ctx.child.cmd 'edit app/src/main/kotlin/com/example/app/Main.kt'
  e2e.expect_kotlin_lsp(ctx.child, ctx.project)
  eq(e2e.clients(ctx.child), { 'kotlin_lsp' })
  e2e.definition_reaches(ctx.child, 'greet', 'lib/src/main/kotlin/com/example/lib/Greeter.kt')
  eq(e2e.errors(ctx.child), {})
end

return T
