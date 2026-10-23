-- Debugger: nvim-dap with a UI and inline variable values
-- https://github.com/mfussenegger/nvim-dap
--
-- Language-agnostic keymaps live here; languages only register adapters/configurations.
--  - Java: nvim-jdtls registers the `java` adapter and discovers main classes when jdtls attaches
--    (needs the java-debug-adapter bundle, see custom/plugins/jdtls.lua). Tests: <leader>ud (neotest).
--  - Kotlin: kotlin_lsp has no debugger, so Mason's kotlin-debug-adapter (fwcd, unmaintained since 2023)
--    is used. Launch runs already compiled classes (`./gradlew classes` first); it does not build.
--    Tests: `./gradlew test --tests '<name>' --debug-jvm`, then attach.

vim.pack.add {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/theHamsta/nvim-dap-virtual-text',
}

local dap = require 'dap'
local dapui = require 'dapui'

---@diagnostic disable-next-line: missing-fields
dapui.setup {}
require('nvim-dap-virtual-text').setup {}

dap.listeners.after.event_initialized['custom-dapui'] = dapui.open
dap.listeners.before.event_terminated['custom-dapui'] = dapui.close
dap.listeners.before.event_exited['custom-dapui'] = dapui.close

-- Attach to a JVM started with `-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005`
-- (e.g. `./gradlew bootRun --debug-jvm`, IntelliJ "Remote JVM Debug"). Launch configs for main
-- classes come from nvim-jdtls.
dap.configurations.java = {
  { type = 'java', request = 'attach', name = 'Attach to JVM (localhost:5005)', hostName = 'localhost', port = 5005 },
}

dap.adapters.kotlin = { type = 'executable', command = 'kotlin-debug-adapter', options = { auto_continue_if_many_stopped = false } }

local function kotlin_project_root() return vim.fs.root(0, { 'settings.gradle.kts', 'settings.gradle', 'gradlew', 'pom.xml' }) or vim.fn.getcwd() end

-- Top-level `fun main` in `Foo.kt` compiles to class `<package>.FooKt`; offer that as the default.
local function kotlin_main_class()
  local pkg = ''
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 50, false)) do
    local name = line:match '^%s*package%s+([%w_.]+)'
    if name then
      pkg = name .. '.'
      break
    end
  end
  local file_class = vim.fn.expand '%:t:r' .. 'Kt'
  return vim.fn.input('Main class: ', pkg .. file_class)
end

dap.configurations.kotlin = {
  { type = 'kotlin', request = 'launch', name = 'Launch main class', projectRoot = kotlin_project_root, mainClass = kotlin_main_class },
  {
    type = 'kotlin',
    request = 'attach',
    name = 'Attach to JVM (localhost:5005)',
    projectRoot = kotlin_project_root,
    hostName = 'localhost',
    port = 5005,
    timeout = 5000,
  },
}

local breakpoint_icons = { Breakpoint = '●', BreakpointCondition = '◆', LogPoint = '◇', BreakpointRejected = '○', Stopped = '▶' }
for name, icon in pairs(breakpoint_icons) do
  local hl = name == 'Stopped' and 'DiagnosticWarn' or 'DiagnosticError'
  vim.fn.sign_define('Dap' .. name, { text = icon, texthl = hl, linehl = name == 'Stopped' and 'Visual' or nil })
end

local function map(keys, func, desc, mode) vim.keymap.set(mode or 'n', keys, func, { desc = 'Debug: ' .. desc }) end

map('<leader>db', dap.toggle_breakpoint, 'Toggle [B]reakpoint')
map('<leader>dB', function() dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, 'Conditional [B]reakpoint')
map('<leader>dL', function() dap.set_breakpoint(nil, nil, vim.fn.input 'Log message: ') end, '[L]og point')
map('<leader>dc', dap.continue, 'Start/[C]ontinue')
map('<leader>dl', dap.run_last, 'Run [L]ast')
map('<leader>dC', dap.run_to_cursor, 'Run to [C]ursor')
map('<leader>di', dap.step_into, 'Step [I]nto')
map('<leader>do', dap.step_over, 'Step [O]ver')
map('<leader>dO', dap.step_out, 'Step [O]ut')
map('<leader>dt', dap.terminate, '[T]erminate')
map('<leader>du', dapui.toggle, 'Toggle [U]I')
map('<leader>de', function() dapui.eval() end, '[E]valuate', { 'n', 'x' })

-- IntelliJ stepping keys
map('<F7>', dap.step_into, 'Step Into')
map('<F8>', dap.step_over, 'Step Over')
map('<S-F8>', dap.step_out, 'Step Out')
map('<F9>', dap.continue, 'Start/Continue')
