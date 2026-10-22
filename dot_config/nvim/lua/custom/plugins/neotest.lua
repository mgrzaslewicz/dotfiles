-- Neotest runs unit tests from inside Neovim
-- https://github.com/nvim-neotest/neotest
--
-- Adapters:
--  - Java: neotest-java (JUnit 5, Maven/Gradle). Uses the running jdtls client for the classpath.
--    The JUnit console launcher jar it needs is downloaded by chezmoi (run_onchange_after_nvim_neotest_java_setup.sh.tmpl).
--  - Kotlin: neotest-gradle (runs `gradlew test`, reads JUnit XML reports). Kotest specs are not detected.

vim.pack.add {
  'https://github.com/nvim-neotest/neotest',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/rcasia/neotest-java',
  'https://github.com/weilbith/neotest-gradle',
}

-- neotest-gradle also matches `*Test.java`, which neotest-java already handles,
-- so limit it to Kotlin to avoid listing Java tests twice.
local gradle_kotlin = setmetatable({
  name = 'neotest-gradle-kotlin',
  is_test_file = function(file_path) return file_path:match 'Test%.kt$' ~= nil end,
}, { __index = require 'neotest-gradle' })

-- neotest-java matches test files by name only (e.g. `FooTest`), so it also claims `FooTest.kt`
-- and then fails looking for Java sources. Limit it to `.java`.
local java_adapter = require 'neotest-java' {}
local java_is_test_file = java_adapter.is_test_file
java_adapter.is_test_file = function(file_path) return file_path:match '%.java$' ~= nil and java_is_test_file(file_path) end

local neotest = require 'neotest'
neotest.setup {
  adapters = {
    java_adapter,
    gradle_kotlin,
  },
}

vim.keymap.set('n', '<leader>ur', function() neotest.run.run() end, { desc = 'Test: [R]un nearest' })
vim.keymap.set('n', '<leader>uf', function() neotest.run.run(vim.fn.expand '%') end, { desc = 'Test: Run [F]ile' })
vim.keymap.set('n', '<leader>ua', function() neotest.run.run(vim.uv.cwd()) end, { desc = 'Test: Run [A]ll' })
vim.keymap.set('n', '<leader>ul', function() neotest.run.run_last() end, { desc = 'Test: Run [L]ast' })
vim.keymap.set('n', '<leader>ux', function() neotest.run.stop() end, { desc = 'Test: Stop' })
vim.keymap.set('n', '<leader>us', function() neotest.summary.toggle() end, { desc = 'Test: Toggle [S]ummary' })
vim.keymap.set('n', '<leader>uo', function() neotest.output.open { enter = true, auto_close = true } end, { desc = 'Test: Show [O]utput' })
vim.keymap.set('n', '<leader>uO', function() neotest.output_panel.toggle() end, { desc = 'Test: Toggle [O]utput panel' })
vim.keymap.set('n', '[u', function() neotest.jump.prev { status = 'failed' } end, { desc = 'Previous failed test' })
vim.keymap.set('n', ']u', function() neotest.jump.next { status = 'failed' } end, { desc = 'Next failed test' })
