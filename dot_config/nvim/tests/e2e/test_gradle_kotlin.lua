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

-- kotlin_lsp answers go to definition of a JDK class with a `jrt:` URI into its own bundled JDK (replayed in
-- tests/test_replay_gradle_kotlin.lua). Such a buffer reads its source from this machine's JDK, and gets the running
-- kotlin_lsp attached for navigation inside it.
T['gradle-kotlin | LSP | a jrt: JDK class buffer shows the local JDK source, with kotlin_lsp attached'] = function()
  ctx.child.cmd 'edit app/src/main/kotlin/com/example/app/Main.kt'
  e2e.wait(ctx.child, 'attach', 'kotlin_lsp attached', "#vim.lsp.get_clients { bufnr = 0, name = 'kotlin_lsp' } > 0")
  ctx.child.cmd 'edit jrt:///kotlin-lsp/jbr!/java.base/java/util/ArrayList.class'
  eq(ctx.child.lua_get "table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\\n'):find('public class ArrayList', 1, true) ~= nil", true)
  e2e.wait(ctx.child, 'attach', 'kotlin_lsp attached to JDK source', "#vim.lsp.get_clients { bufnr = 0, name = 'kotlin_lsp' } > 0")
end

-- kotlin_lsp has no document symbols for a `jar:` JDK source, so gO lists its declarations from the tree-sitter parse.
T['gradle-kotlin | LSP | document symbols of a JDK source list its declarations (tree-sitter, server has none)'] = function()
  eq(
    ctx.child.lua_get [[require('custom.jvm.jdk_source').declarations(table.concat({
      'package java.util;', 'public class ArrayList<E> {', '  private int size;', '  public ArrayList() {}', '  public boolean add(E e) { return true; }', '  static class Itr {}', '}',
    }, '\n'))]],
    {
      { text = 'ArrayList', kind = 'Class', lnum = 2, col = 13 },
      { text = 'ArrayList', kind = 'Constructor', lnum = 4, col = 9 },
      { text = 'add', kind = 'Method', lnum = 5, col = 17 },
      { text = 'Itr', kind = 'Class', lnum = 6, col = 15 },
    }
  )
end

-- Pasting a line with an unimported type imports it: kotlin_lsp offers one import per package of the class, here
-- kotlin.time.Duration, java.time.Duration and javax.xml.datatype.Duration; the picker answers the first.
T['gradle-kotlin | paste | a pasted line with an unimported type gets its import'] = function()
  ctx.child.cmd 'edit app/src/main/kotlin/com/example/app/Main.kt'
  e2e.wait(ctx.child, 'attach', 'kotlin_lsp attached', "#vim.lsp.get_clients { bufnr = 0, name = 'kotlin_lsp' } > 0")
  -- Autosave writes the buffer to the fixture 1 s after a change, so the case restores the file at the end: later
  -- cases compile it.
  ctx.child.lua [=[
    _G.paste_original = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    vim.fn.setreg('a', { 'val probeDuration: Duration? = null' }, 'l')
    _G.select_before_paste = vim.ui.select
    vim.ui.select = function(items, _, on_choice) on_choice(items[1]) end
  ]=]
  ctx.child.type_keys 'G"ap'
  e2e.wait(ctx.child, 'index', 'import of Duration added', "vim.tbl_contains(vim.api.nvim_buf_get_lines(0, 0, -1, false), 'import kotlin.time.Duration')")
  ctx.child.lua [=[
    vim.ui.select = _G.select_before_paste
    vim.api.nvim_buf_set_lines(0, 0, -1, false, _G.paste_original)
  ]=]
  ctx.child.cmd 'silent! write'
end

T['gradle-kotlin | tasks | kotlinc errors from `gradle classes` land in quickfix, once each'] = function()
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

-- kotlin-debug-adapter launches already compiled classes. A breakpoint in the launched main class itself is
-- often missed (custom/plugins/debug.lua), so these stop in a class loaded later.
T['gradle-kotlin | debug | <leader>dc launches fun main from a module and stops in another module'] = function()
  eq(vim.system({ 'gradle', '-q', 'classes' }, { cwd = ctx.project }):wait().code, 0)
  ctx.child.cmd 'edit app/src/main/kotlin/com/example/app/Main.kt'
  local stopped = e2e.debug_until_stopped(
    ctx.child,
    ctx.project,
    { file = 'lib/src/main/kotlin/com/example/lib/Greeter.kt', at = 'fun greet', keys = ' dc', pick = 'Launch' }
  )
  eq(stopped, { file = 'lib/src/main/kotlin/com/example/lib/Greeter.kt', line = 4 })
  MiniTest.expect.no_equality(e2e.debug_to_end(ctx.child):find('Hello, Ada', 1, true), nil)
end

return T
