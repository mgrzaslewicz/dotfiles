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

T['gradle-mixed | tasks | kotlinc errors from `gradle classes` land in quickfix, once each'] = function()
  local items = e2e.compile_errors(
    ctx.child,
    ctx.project,
    'src/main/kotlin/com/example/mixed/Broken.kt',
    { 'package com.example.mixed', '', 'fun broken(): Int = missing' },
    'gradle classes'
  )
  eq(vim.tbl_filter(function(i) return i.type == 'E' end, items), { { file = 'src/main/kotlin/com/example/mixed/Broken.kt', lnum = 3, type = 'E' } })
end

T['gradle-mixed | neotest | Java test file: per-test results, listed once (neotest-java)'] = function()
  ctx.child.cmd 'edit src/test/java/com/example/mixed/JavaGreeterTest.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  eq(
    e2e.neotest_run_file(ctx.child),
    { tests = { ['neotest-java'] = { 'greets', 'failsOnPurpose' } }, results = { greets = 'passed', failsOnPurpose = 'failed' } }
  )
end

T['gradle-mixed | neotest | Kotlin test file: per-test results, listed once (neotest-gradle-kotlin)'] = function()
  ctx.child.cmd 'edit src/test/kotlin/com/example/mixed/KotlinFormatterTest.kt'
  eq(
    e2e.neotest_run_file(ctx.child),
    { tests = { ['neotest-gradle-kotlin'] = { 'shouts', 'fails on purpose' } }, results = { shouts = 'passed', ['fails on purpose'] = 'failed' } }
  )
end

return T
