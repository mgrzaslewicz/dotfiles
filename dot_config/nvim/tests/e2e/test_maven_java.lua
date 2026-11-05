-- Multi-module Maven build with Lombok and JUnit 5 (fixtures/maven-java), same sources as gradle-java.
local e2e = require 'tests.e2e.helpers'
local eq = MiniTest.expect.equality

local T, ctx = e2e.fixture_set 'maven-java'

T['maven-java | LSP | jdtls attaches at the build root, resolves Lombok getters, reports no errors'] = function()
  ctx.child.cmd 'edit app/src/main/java/com/example/app/Main.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  e2e.definition_reaches(ctx.child, 'getName', 'model/src/main/java/com/example/model/Person.java')
  eq(e2e.errors(ctx.child), {})
end

T['maven-java | LSP | grm answers on a method calling one without a result type, without an error message'] = function()
  ctx.child.cmd 'edit app/src/main/java/com/example/app/Main.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  e2e.definition_reaches(ctx.child, 'getName', 'model/src/main/java/com/example/model/Person.java')
  ctx.child.cmd 'messages clear'
  ctx.child.lua [[
    vim.fn.cursor(vim.fn.search 'println', 1)
    _G.e2e.method_types = nil
    require('custom.method_types').collect(function(types)
      _G.e2e.method_types = vim.tbl_map(function(t) return vim.fs.basename(vim.uri_to_fname(t.uri)) end, types or {})
    end)
  ]]
  e2e.wait(ctx.child, 'edit', 'method types collected', '_G.e2e.method_types ~= nil')
  eq(vim.tbl_contains(ctx.child.lua_get '_G.e2e.method_types', 'Person.java'), true)
  eq(ctx.child.lua_get "vim.api.nvim_exec2('messages', { output = true }).output", '')
end

T['maven-java | tasks | javac errors from `mvn compile` land in quickfix, once each'] = function()
  local items = e2e.compile_errors(
    ctx.child,
    ctx.project,
    'app/src/main/java/com/example/app/Broken.java',
    { 'package com.example.app;', '', 'class Broken {', '  int value() { return missing; }', '}' },
    'mvn compile'
  )
  eq(vim.tbl_filter(function(i) return i.type == 'E' end, items), { { file = 'app/src/main/java/com/example/app/Broken.java', lnum = 4, type = 'E' } })
end

return T
