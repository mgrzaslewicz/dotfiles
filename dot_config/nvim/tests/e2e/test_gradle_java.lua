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

T['gradle-java | tasks | javac errors from `gradle classes` land in quickfix, known limit: twice'] = function()
  local items = e2e.compile_errors(
    ctx.child,
    ctx.project,
    'app/src/main/java/com/example/app/Broken.java',
    { 'package com.example.app;', '', 'class Broken {', '  int value() { return missing; }', '}' },
    'gradle classes'
  )
  -- Known limit: Gradle repeats javac errors in its failure summary, so each one is listed twice.
  local err = { file = 'app/src/main/java/com/example/app/Broken.java', lnum = 4, type = 'E' }
  eq(vim.tbl_filter(function(i) return i.type == 'E' end, items), { err, err })
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

return T
