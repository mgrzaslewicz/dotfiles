local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set {
  hooks = {
    pre_case = function() child.start() end,
    post_case = function() child.stop() end,
  },
}

-- A multi-module Gradle build with a JUnit report for one Kotlin test in `app`.
local function gradle_build()
  return helpers.tree {
    ['settings.gradle.kts'] = '',
    ['build.gradle.kts'] = '',
    ['app/build.gradle.kts'] = '',
    ['app/src/test/kotlin/MainTest.kt'] = '',
    ['app/build/test-results/test/TEST-com.example.MainTest.xml'] = '<testsuite name="com.example.MainTest"><testcase name="greets()" classname="com.example.MainTest"/></testsuite>',
  }
end

-- Statuses neotest-gradle-kotlin reports after running `run` (the build root or the test file). Gradle itself is
-- not run: its `properties` call answers `testResultsDir: null`, as Gradle 9 does.
local function kotlin_results(dir, run)
  return child.lua(
    [[
    local dir, run = ...
    require('neotest.lib').process.run = function() return 0, { stdout = 'testResultsDir: null\n' } end
    local adapter = vim.iter(require('neotest.config').adapters):find(function(a) return a.name == 'neotest-gradle-kotlin' end)
    local file = dir .. '/app/src/test/kotlin/MainTest.kt'
    local positions = {
      { id = file, type = 'file', path = file, name = 'MainTest.kt', range = { 0, 0, 9, 0 } },
      { { id = 'com.example.MainTest.greets', type = 'test', path = file, name = 'greets', range = { 2, 0, 4, 0 } } },
    }
    if run == 'root' then positions = { { id = dir, type = 'dir', path = dir, name = 'root' }, positions } end
    local tree = require('neotest.types').Tree.from_list(positions, function(pos) return pos.id end)
    local statuses
    require('nio').run(function()
      local results = adapter.results(adapter.build_spec { tree = tree }, { code = 1, output = '' }, tree)
      statuses = vim.tbl_map(function(r) return r.status end, results)
    end)
    vim.wait(5000, function() return statuses ~= nil end)
    return statuses
  ]],
    { dir, run }
  )
end

-- Gradle 9 answers neotest-gradle's `properties --property testResultsDir` with `null`, so it looked for JUnit
-- reports in `null/test` and showed every Kotlin test as skipped.
T['Kotlin test file run reads JUnit reports from its module, whatever Gradle says about testResultsDir'] = function()
  eq(kotlin_results(gradle_build(), 'file'), { ['com.example.MainTest.greets'] = 'passed' })
end

-- Run all hands the adapter the build root; the reports are in the modules.
T['Kotlin run all reads JUnit reports from every module'] = function()
  eq(kotlin_results(gradle_build(), 'root'), { ['com.example.MainTest.greets'] = 'passed' })
end

return T
