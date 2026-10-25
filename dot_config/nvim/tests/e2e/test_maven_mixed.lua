-- Multi-module Maven build, Java and Kotlin calling each other in core, Kotlin app (fixtures/maven-mixed).
local e2e = require 'tests.e2e.helpers'
local eq = MiniTest.expect.equality

local T, ctx = e2e.fixture_set 'maven-mixed'

T['maven-mixed | LSP | Java files get jdtls only, at the build root, without errors'] = function()
  ctx.child.cmd 'edit core/src/main/java/com/example/mixed/JavaGreeter.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  eq(e2e.clients(ctx.child), { 'jdtls' })
  eq(e2e.errors(ctx.child), {})
end

T['maven-mixed | LSP | Kotlin files get kotlin_lsp only, at the build root, resolving Java classes'] = function()
  ctx.child.cmd 'edit app/src/main/kotlin/com/example/app/Main.kt'
  e2e.expect_kotlin_lsp(ctx.child, ctx.project)
  eq(e2e.clients(ctx.child), { 'kotlin_lsp' })
  e2e.definition_reaches(ctx.child, 'greet', 'core/src/main/java/com/example/mixed/JavaGreeter.java')
  eq(e2e.errors(ctx.child), {})
end

-- Known limit: jdtls has no Kotlin support, so Java code using a Kotlin class gets an error and no navigation
-- (Gradle and Maven compile it fine). Turns red if jdtls ever resolves it. See custom/plugins/jdtls.lua.
T['maven-mixed | LSP | known limit: jdtls reports Kotlin classes used from Java as unresolved'] = function()
  ctx.child.cmd 'edit core/src/main/java/com/example/mixed/Report.java'
  e2e.expect_jdtls(ctx.child, ctx.project)
  e2e.wait(
    ctx.child,
    'index',
    'jdtls error about KotlinFormatter in Report.java',
    "vim.iter(vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })):any(function(d) return d.message:find('KotlinFormatter', 1, true) end)"
  )
end

T['maven-mixed | tasks | kotlin-maven-plugin errors from `mvn compile` land in quickfix, once each'] = function()
  local items = e2e.compile_errors(
    ctx.child,
    ctx.project,
    'core/src/main/kotlin/com/example/mixed/Broken.kt',
    { 'package com.example.mixed', '', 'fun broken(): Int = missing' },
    'mvn compile'
  )
  eq(vim.tbl_filter(function(i) return i.type == 'E' end, items), { { file = 'core/src/main/kotlin/com/example/mixed/Broken.kt', lnum = 3, type = 'E' } })
end

T['maven-mixed | neotest | Kotlin test file: per-test results, listed once (neotest-maven-kotlin)'] = function()
  ctx.child.cmd 'edit app/src/test/kotlin/com/example/app/MainTest.kt'
  eq(
    e2e.neotest_run_file(ctx.child),
    { tests = { ['neotest-maven-kotlin'] = { 'headline', 'fails on purpose' } }, results = { headline = 'passed', ['fails on purpose'] = 'failed' } }
  )
end

-- Known limit: kotlin-debug-adapter puts sibling modules on the classpath only from ~/.m2 (`mvn install`), so
-- launching from a module that uses another one fails once that module's classes are needed. With the build root
-- as projectRoot the main class itself is not found. See custom/plugins/debug.lua.
T['maven-mixed | debug | known limit: <leader>dc launch lacks the sibling module classes'] = function()
  eq(vim.system({ 'mvn', '-q', 'compile' }, { cwd = ctx.project }):wait().code, 0)
  ctx.child.cmd 'edit app/src/main/kotlin/com/example/app/Main.kt'
  ctx.child.lua [[
    _G.e2e = _G.e2e or {}
    _G.e2e.dap_output = {}
    require('dap').listeners.after.event_output['e2e'] = function(_, body)
      if body.category ~= 'console' then table.insert(_G.e2e.dap_output, body.output) end
    end
    vim.fn.input = function(_, default) return default end
    vim.ui.select = function(items, o, on_choice)
      for _, item in ipairs(items) do
        if (o.format_item or tostring)(item):find 'Launch' then return on_choice(item) end
      end
    end
  ]]
  ctx.child.type_keys ' dc'
  e2e.wait(
    ctx.child,
    'dap',
    'NoClassDefFoundError for the core module',
    "table.concat(_G.e2e.dap_output, ''):find('NoClassDefFoundError: com/example/mixed/KotlinFormatter', 1, true)"
  )
  e2e.wait(ctx.child, 'dap', 'debuggee ended', "require('dap').session() == nil")
end

return T
