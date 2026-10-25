-- Multi-module Gradle build with Lombok and JUnit 5 (fixtures/gradle-java).
local e2e = require 'tests.e2e.helpers'
local eq = MiniTest.expect.equality

local T, ctx = e2e.fixture_set 'gradle-java'

T['gradle-java | LSP | jdtls attaches at the build root, resolves Lombok getters, reports no errors'] = function()
  ctx.child.cmd 'edit app/src/main/java/com/example/app/Main.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  e2e.definition_reaches(ctx.child, 'getName', 'model/src/main/java/com/example/model/Person.java')
  eq(e2e.errors(ctx.child), {})
end

T['gradle-java | tasks | javac errors from `gradle classes` land in quickfix, once each'] = function()
  local items = e2e.compile_errors(
    ctx.child,
    ctx.project,
    'app/src/main/java/com/example/app/Broken.java',
    { 'package com.example.app;', '', 'class Broken {', '  int value() { return missing; }', '}' },
    'gradle classes'
  )
  eq(vim.tbl_filter(function(i) return i.type == 'E' end, items), { { file = 'app/src/main/java/com/example/app/Broken.java', lnum = 4, type = 'E' } })
end

T['gradle-java | neotest | JUnit file run: per-test results, listed once (neotest-java)'] = function()
  ctx.child.cmd 'edit app/src/test/java/com/example/app/MainTest.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  eq(
    e2e.neotest_run_file(ctx.child),
    { tests = { ['neotest-java'] = { 'greets', 'failsOnPurpose' } }, results = { greets = 'passed', failsOnPurpose = 'failed' } }
  )
end

T['gradle-java | refactor | <leader>rv on an expression asks which one, then extracts it'] = function()
  ctx.child.cmd 'edit app/src/main/java/com/example/app/Main.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  local lines = e2e.refactor(ctx.child, { text = '"Hello, "', keys = ' rv', pick = '"Hello, " + name', from = 'static String greeting' })
  eq(lines, { '    static String greeting(String name) {', '        String string = "Hello, " + name;', '        return string;', '    }', '}' })
end

T['gradle-java | refactor | visual <leader>rv extracts the selection'] = function()
  ctx.child.cmd 'edit app/src/main/java/com/example/app/Main.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  local lines = e2e.refactor(ctx.child, { text = '"Hello, " + name', visual = true, keys = ' rv', from = 'static String greeting' })
  eq(lines, { '    static String greeting(String name) {', '        String string = "Hello, " + name;', '        return string;', '    }', '}' })
end

T['gradle-java | refactor | visual <leader>rm extracts the selection into a method'] = function()
  ctx.child.cmd 'edit app/src/main/java/com/example/app/Main.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  local lines =
    e2e.refactor(ctx.child, { text = 'System.out.println(greeting(person.getName()));', visual = true, keys = ' rm', from = 'public static void main' })
  eq(vim.list_slice(lines, 1, 8), {
    '    public static void main(String[] args) {',
    '        Person person = new Person("Ada");',
    '        extracted(person);',
    '    }',
    '',
    '    private static void extracted(Person person) {',
    '        System.out.println(greeting(person.getName()));',
    '    }',
  })
end

T['gradle-java | debug | <leader>dc launches the main class and stops at a breakpoint'] = function()
  ctx.child.cmd 'edit app/src/main/java/com/example/app/Main.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  local stopped = e2e.debug_until_stopped(ctx.child, ctx.project, { at = 'return "Hello, "', keys = ' dc', pick = 'Main' })
  eq(stopped, { file = 'app/src/main/java/com/example/app/Main.java', line = 13 })
  e2e.debug_stop(ctx.child)
end

T['gradle-java | debug | <leader>ud debugs the nearest test and stops at a breakpoint in it'] = function()
  ctx.child.cmd 'edit app/src/test/java/com/example/app/MainTest.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  local stopped = e2e.debug_until_stopped(ctx.child, ctx.project, { at = 'assertEquals("Hello, Ada"', keys = ' ud' })
  eq(stopped, { file = 'app/src/test/java/com/example/app/MainTest.java', line = 10 })
  e2e.debug_stop(ctx.child)
end

-- Last in the file: stops the shared child, as two jdtls on one workspace conflict.
T['gradle-java | sessions | nvim in the project restores the splits of the last exit, with jdtls, without panels'] = function()
  ctx.child.stop()
  local helpers = require 'tests.helpers'
  local first, second = helpers.new_child(), helpers.new_child()
  MiniTest.finally(function()
    first.stop()
    second.stop()
  end)
  first.start { '--cmd', 'cd ' .. ctx.project }
  first.cmd 'edit app/src/main/java/com/example/app/Main.java'
  first.cmd 'vsplit model/src/main/java/com/example/model/Person.java'
  first.cmd 'Neotree show'
  first.cmd 'copen'
  pcall(first.cmd, 'qall!')
  first.stop()

  second.start { '--cmd', 'cd ' .. ctx.project }
  local windows = second.lua [[
    local ret = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buf = vim.api.nvim_win_get_buf(win)
      local name = vim.api.nvim_buf_get_name(buf)
      -- A panel saved in the session comes back as an empty window.
      table.insert(ret, vim.bo[buf].buftype ~= '' and ('panel: ' .. vim.bo[buf].filetype) or name == '' and 'empty window' or vim.fs.relpath(vim.fn.getcwd(), name) or name)
    end
    table.sort(ret)
    return ret
  ]]
  eq(windows, { 'app/src/main/java/com/example/app/Main.java', 'model/src/main/java/com/example/model/Person.java' })
  -- Started by the restore itself, so without the ServiceReady hook of `expect_jdtls`.
  second.cmd 'buffer app/src/main/java/com/example/app/Main.java'
  e2e.wait(second, 'attach', 'jdtls attached', "#vim.lsp.get_clients { bufnr = 0, name = 'jdtls' } > 0")
  eq(second.lua_get "vim.lsp.get_clients({ bufnr = 0, name = 'jdtls' })[1].root_dir", ctx.project)
end

return T
