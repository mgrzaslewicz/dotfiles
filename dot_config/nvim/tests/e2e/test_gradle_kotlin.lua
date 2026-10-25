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

T['gradle-kotlin | tasks | kotlinc errors from `gradle classes` land in quickfix'] = function()
  local items = e2e.compile_errors(
    ctx.child,
    ctx.project,
    'app/src/main/kotlin/com/example/app/Broken.kt',
    { 'package com.example.app', '', 'fun broken(): Int = missing' },
    'gradle classes'
  )
  eq(vim.tbl_filter(function(i) return i.type == 'E' end, items), { { file = 'app/src/main/kotlin/com/example/app/Broken.kt', lnum = 3, type = 'E' } })
end

T['gradle-kotlin | neotest | JUnit file run: per-test results, listed once (neotest-gradle-kotlin)'] = function()
  ctx.child.cmd 'edit app/src/test/kotlin/com/example/app/MainTest.kt'
  eq(
    e2e.neotest_run_file(ctx.child),
    { tests = { ['neotest-gradle-kotlin'] = { 'greets', 'fails on purpose' } }, results = { greets = 'passed', ['fails on purpose'] = 'failed' } }
  )
end

-- Run all hands neotest-java the root of a project without Java tests; it used to fail there
-- (custom/plugins/neotest.lua).
T['gradle-kotlin | neotest | run all in a Kotlin-only project'] = function()
  ctx.child.cmd 'edit app/src/test/kotlin/com/example/app/MainTest.kt'
  ctx.child.cmd 'messages clear'
  eq(e2e.neotest_run_file(ctx.child, ' ua').results, { greets = 'passed', ['fails on purpose'] = 'failed' })
  eq(ctx.child.lua_get "vim.api.nvim_exec2('messages', { output = true }).output", '')
end

T['gradle-kotlin | refactor | <leader>rv extracts the expression at the cursor'] = function()
  ctx.child.cmd 'edit app/src/main/kotlin/com/example/app/Main.kt'
  e2e.expect_kotlin_lsp(ctx.child, ctx.project)
  local lines = e2e.refactor(ctx.child, { text = 'greeting("Ada")', keys = ' rv', from = 'val greeting' })
  eq(lines, { '    val greeting = greeting("Ada")', '    println(greeting!!)', '}' })
end

T['gradle-kotlin | refactor | visual <leader>rv extracts the selection'] = function()
  ctx.child.cmd 'edit app/src/main/kotlin/com/example/app/Main.kt'
  e2e.expect_kotlin_lsp(ctx.child, ctx.project)
  local lines = e2e.refactor(ctx.child, { text = 'greeting("Ada")', visual = true, keys = ' rv', from = 'val greeting' })
  eq(lines, { '    val greeting = greeting("Ada")', '    println(greeting!!)', '}' })
end

-- Known limit: kotlin-lsp offers no extract function/method action. See custom/refactor.lua.
T['gradle-kotlin | refactor | known limit: visual <leader>rm has no action'] = function()
  ctx.child.cmd 'edit app/src/main/kotlin/com/example/app/Main.kt'
  e2e.expect_kotlin_lsp(ctx.child, ctx.project)
  ctx.child.cmd 'messages clear'
  ctx.child.lua [[
    local line = vim.fn.search('println', 'n')
    vim.api.nvim_win_set_cursor(0, { line, 4 })
  ]]
  ctx.child.type_keys('v', '$', 'h', ' rm')
  e2e.wait(
    ctx.child,
    'edit',
    'No code actions available',
    "vim.api.nvim_exec2('messages', { output = true }).output:find('No code actions available', 1, true)"
  )
end

return T
