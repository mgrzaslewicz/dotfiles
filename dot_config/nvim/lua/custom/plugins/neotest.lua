-- Neotest runs unit tests from inside Neovim
-- https://github.com/nvim-neotest/neotest
--
-- Adapters:
--  - Java: neotest-java (JUnit 5, Maven/Gradle). Uses the running jdtls client for the classpath.
--    The JUnit console launcher jar it needs is downloaded by chezmoi (run_onchange_after_nvim_neotest_java_setup.sh.tmpl).
--  - Kotlin: neotest-gradle (runs `gradlew test`, reads JUnit XML reports). Kotest specs are not detected. It shows
--    test names in words (`failsOnPurpose` as "fails on purpose").
--  - Kotlin in Maven: no plugin covers it, so `neotest-maven-kotlin` below reuses neotest-gradle's Kotlin test
--    discovery and JUnit report parsing, and runs `mvn test` (with `-pl <module> -am` for a file or test).
--  - Known limit (upstream): after `:bwipeout` of a test file with failures, the next run errors in neotest's
--    diagnostic consumer ("Invalid buffer id"). `:bdelete` is fine.

vim.pack.add {
  'https://github.com/nvim-neotest/neotest',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/rcasia/neotest-java',
  'https://github.com/weilbith/neotest-gradle',
}

local gradle = require 'neotest-gradle'

-- neotest-gradle also matches `*Test.java`, which neotest-java already handles,
-- so limit it to Kotlin to avoid listing Java tests twice.
local gradle_kotlin = setmetatable({
  name = 'neotest-gradle-kotlin',
  is_test_file = function(file_path) return file_path:match 'Test%.kt$' ~= nil end,
}, { __index = gradle })

-- neotest-gradle asks Gradle for `testResultsDir`, which Gradle 9 answers with `null`: no JUnit reports were
-- found and every test showed as skipped. And for run all it reads only the root project's reports. Instead,
-- read Gradle's default report dir (`build/test-results/test`) of every module below what was run: the test's
-- module, or the directory. A custom `reports` location is not supported.
gradle_kotlin.build_spec = function(args)
  local spec = gradle.build_spec(args)
  if not spec then return end
  local pos = args.tree:data()
  spec.context.reports_root = pos.type == 'dir' and pos.path or require 'neotest-gradle.hooks.find_project_directory'(pos.path)
  return spec
end
gradle_kotlin.results = function(spec, result, tree)
  local is_report_dir = function(name, path) return name == 'test' and vim.endswith(path, '/build/test-results') end
  local ret = {}
  for _, dir in ipairs(vim.fs.find(is_report_dir, { path = spec.context.reports_root, type = 'directory', limit = math.huge })) do
    spec.context.test_resuls_directory = dir
    ret = vim.tbl_extend('force', ret, gradle.results(spec, result, tree))
  end
  return ret
end

-- neotest-java matches test files by name only (e.g. `FooTest`), so it also claims `FooTest.kt`
-- and then fails looking for Java sources. Limit it to `.java`.
local java_adapter = require 'neotest-java' {}
local java_is_test_file = java_adapter.is_test_file
java_adapter.is_test_file = function(file_path) return file_path:match '%.java$' ~= nil and java_is_test_file(file_path) end

-- In a Kotlin-only project neotest still hands the root dir to neotest-java, which then
-- asserts there is a `.java` file to attach jdtls to. Skip trees without Java tests.
local java_build_spec = java_adapter.build_spec
java_adapter.build_spec = function(args)
  for _, node in args.tree:iter_nodes() do
    if node:data().type == 'test' then return java_build_spec(args) end
  end
end

local project = require 'custom.jvm.project'
local maven_kotlin = {
  name = 'neotest-maven-kotlin',
  root = function(dir)
    local build = project.root(dir)
    return build and build.tool == 'maven' and build.root or nil
  end,
  filter_dir = function(name) return name ~= 'target' and name ~= 'node_modules' and not vim.startswith(name, '.') end,
  is_test_file = function(file_path) return file_path:match 'Test%.kt$' ~= nil end,
  discover_positions = gradle.discover_positions,
  build_spec = function(args)
    local pos = args.tree:data()
    local build = assert(project.root(pos.type == 'dir' and pos.path or vim.fs.dirname(pos.path)))
    local command = { 'mvn', 'test' }
    if pos.type ~= 'dir' then
      local module = vim.fs.relpath(build.root, vim.fs.root(pos.path, 'pom.xml') or build.root) or '.'
      -- Surefire wants Class#method; neotest-gradle's position ids are Class.method.
      local filter = pos.type == 'test' and pos.id:gsub('%.([^.]+)$', '#%1')
        or table.concat(vim.iter(args.tree:iter()):filter(function(_, p) return p.type == 'namespace' end):map(function(_, p) return p.id end):totable(), ',')
      vim.list_extend(command, { '-pl', module, '-am', '-Dtest=' .. filter, '-Dsurefire.failIfNoSpecifiedTests=false' })
    end
    return { command = command, cwd = build.root, context = { reports_root = pos.type == 'dir' and pos.path or vim.fs.root(pos.path, 'pom.xml') } }
  end,
  -- Surefire's XML reports (JUnit format). Not neotest-gradle's parser: it reads every file in the directory and
  -- fails on surefire's .txt summaries next to them.
  results = function(spec, _, tree)
    local xml, files = require 'neotest.lib.xml', require('neotest.lib').files
    local as_list = function(value) return (type(value) == 'table' and #value > 0) and value or { value } end
    local ret, run = {}, {}
    for _, pos in tree:iter() do
      run[pos.id] = true
    end
    local is_report_dir = function(name, path) return name == 'surefire-reports' and vim.endswith(path, '/target') end
    for _, dir in ipairs(vim.fs.find(is_report_dir, { path = spec.context.reports_root, type = 'directory', limit = math.huge })) do
      for name, type in vim.fs.dir(dir) do
        if type == 'file' and name:match '^TEST%-.*%.xml$' then
          local report = xml.parse(files.read(vim.fs.joinpath(dir, name)))
          for _, suite in ipairs(as_list(report.testsuite)) do
            for _, case in ipairs(as_list(suite.testcase)) do
              local id = case._attr.classname .. '.' .. case._attr.name:gsub('%(.*%)$', '')
              if run[id] then
                local problem = case.failure or case.error
                ret[id] = {
                  status = problem and 'failed' or case.skipped and 'skipped' or 'passed',
                  short = problem and problem._attr and problem._attr.message,
                  errors = problem and { { message = problem._attr and problem._attr.message or '' } } or nil,
                }
              end
            end
          end
        end
      end
    end
    return ret
  end,
}

local neotest = require 'neotest'
---@diagnostic disable-next-line: missing-fields
neotest.setup {
  adapters = {
    java_adapter,
    gradle_kotlin,
    maven_kotlin,
  },
}

vim.keymap.set('n', '<leader>ur', function() neotest.run.run() end, { desc = 'Test: [R]un nearest' })
vim.keymap.set('n', '<leader>uf', function() neotest.run.run(vim.fn.expand '%') end, { desc = 'Test: Run [F]ile' })
vim.keymap.set('n', '<leader>ua', function() neotest.run.run(vim.uv.cwd()) end, { desc = 'Test: Run [A]ll' })
---@diagnostic disable-next-line: missing-fields
vim.keymap.set('n', '<leader>ud', function() neotest.run.run { strategy = 'dap' } end, { desc = 'Test: [D]ebug nearest' })
vim.keymap.set('n', '<leader>ul', function() neotest.run.run_last() end, { desc = 'Test: Run [L]ast' })
vim.keymap.set('n', '<leader>ux', function() neotest.run.stop() end, { desc = 'Test: Stop' })
vim.keymap.set('n', '<leader>us', function() neotest.summary.toggle() end, { desc = 'Test: Toggle [S]ummary' })
vim.keymap.set('n', '<leader>uo', function() neotest.output.open { enter = true, auto_close = true } end, { desc = 'Test: Show [O]utput' })
vim.keymap.set('n', '<leader>uO', function() neotest.output_panel.toggle() end, { desc = 'Test: Toggle [O]utput panel' })
vim.keymap.set('n', '[u', function() neotest.jump.prev { status = 'failed' } end, { desc = 'Previous failed test' })
vim.keymap.set('n', ']u', function() neotest.jump.next { status = 'failed' } end, { desc = 'Next failed test' })
