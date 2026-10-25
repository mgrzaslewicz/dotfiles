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

-- A multi-module Maven build with a surefire report for one Kotlin test in `app`.
local function maven_build()
  return helpers.tree {
    ['pom.xml'] = '',
    ['app/pom.xml'] = '',
    ['app/src/test/kotlin/MainTest.kt'] = '',
    ['app/target/surefire-reports/TEST-com.example.MainTest.xml'] = '<testsuite name="com.example.MainTest"><testcase name="greets" classname="com.example.MainTest"><failure message="expected: x" type="org.opentest4j.AssertionFailedError">at com.example.MainTest.greets(MainTest.kt:9)</failure></testcase><testcase name="waves()" classname="com.example.MainTest"><error message="boom" type="java.lang.IllegalStateException"/></testcase></testsuite>',
    -- surefire's plain-text summary next to the XML report
    ['app/target/surefire-reports/com.example.MainTest.txt'] = 'Tests run: 2, Failures: 1, Errors: 1 <<< FAILURE!',
  }
end

-- What neotest-maven-kotlin builds and reports for `run`: the build root, the test file or the test `greets`.
local function maven_kotlin(dir, run)
  return child.lua(
    [[
    local dir, run = ...
    local adapter = vim.iter(require('neotest.config').adapters):find(function(a) return a.name == 'neotest-maven-kotlin' end)
    local file = dir .. '/app/src/test/kotlin/MainTest.kt'
    local test = { id = 'com.example.MainTest.greets', type = 'test', path = file, name = 'greets', range = { 2, 0, 4, 0 } }
    local waves = { id = 'com.example.MainTest.waves', type = 'test', path = file, name = 'waves', range = { 5, 0, 7, 0 } }
    local positions = {
      { id = file, type = 'file', path = file, name = 'MainTest.kt', range = { 0, 0, 9, 0 } },
      { { id = 'com.example.MainTest', type = 'namespace', path = file, name = 'MainTest', range = { 1, 0, 8, 0 } }, { test }, { waves } },
    }
    if run == 'root' then positions = { { id = dir, type = 'dir', path = dir, name = 'root' }, positions } end
    local tree = require('neotest.types').Tree.from_list(positions, function(pos) return pos.id end)
    local ret
    require('nio').run(function()
      local run_tree = run == 'test' and tree:get_key(test.id) or tree
      local spec = adapter.build_spec { tree = run_tree }
      local results = adapter.results(spec, { code = 1, output = '' }, run_tree)
      ret = { root = adapter.root(dir .. '/app'), test_file = adapter.is_test_file(file), command = spec.command, cwd = spec.cwd, statuses = vim.tbl_map(function(r) return r.status end, results) }
    end)
    vim.wait(5000, function() return ret ~= nil end)
    return ret
  ]],
    { dir, run }
  )
end

T['Kotlin test in Maven runs mvn test for its module and the modules it needs'] = function()
  local dir = maven_build()
  eq(maven_kotlin(dir, 'test'), {
    root = dir,
    test_file = true,
    command = { 'mvn', 'test', '-pl', 'app', '-am', '-Dtest=com.example.MainTest#greets', '-Dsurefire.failIfNoSpecifiedTests=false' },
    cwd = dir,
    statuses = { ['com.example.MainTest.greets'] = 'failed' },
  })
end

T['Kotlin test file in Maven runs its classes'] = function()
  local dir = maven_build()
  local ret = maven_kotlin(dir, 'file')
  eq(ret.command, { 'mvn', 'test', '-pl', 'app', '-am', '-Dtest=com.example.MainTest', '-Dsurefire.failIfNoSpecifiedTests=false' })
  eq(ret.statuses, { ['com.example.MainTest.greets'] = 'failed', ['com.example.MainTest.waves'] = 'failed' })
end

T['Kotlin run all in Maven runs every module and reads all their reports'] = function()
  local dir = maven_build()
  local ret = maven_kotlin(dir, 'root')
  eq(ret.command, { 'mvn', 'test' })
  eq(ret.statuses, { ['com.example.MainTest.greets'] = 'failed', ['com.example.MainTest.waves'] = 'failed' })
end

return T
