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

return T
