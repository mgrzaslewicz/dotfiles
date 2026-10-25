-- Run by tests/run.sh --e2e in an nvim that loaded the config (plugins are installed by then). Waits for the
-- installs the config starts on its own, then checks that the result matches the pins in custom/tools.lua.
-- Also downloads the JUnit console launcher neotest-java needs, as the chezmoi script does on the host
-- (run_onchange_after_nvim_neotest_java_setup.sh).
local tools = require 'custom.tools'

local function fail(message)
  io.stderr:write('e2e bootstrap: ' .. message .. '\n')
  vim.cmd 'cquit 1'
end

local ok, err = pcall(function()
  require('mason-tool-installer').check_install(false, true)
  require('nvim-treesitter').install(tools.parsers):wait(10 * 60 * 1000)
  vim.ui.select = function(choices, _, on_choice) on_choice(choices[1]) end
  vim.cmd 'NeotestJava setup'
  io.stdout:write '\n'
end)
if not ok then return fail(tostring(err)) end

local registry = require 'mason-registry'
local wrong = {}
for _, tool in ipairs(tools.mason) do
  local installed = registry.is_installed(tool[1]) and registry.get_package(tool[1]):get_installed_version() or 'not installed'
  if installed ~= tool.version then table.insert(wrong, ('%s: %s, pinned %s'):format(tool[1], installed, tool.version)) end
end
local parsers = require('nvim-treesitter').get_installed 'parsers'
for _, parser in ipairs(tools.parsers) do
  if not vim.list_contains(parsers, parser) then table.insert(wrong, 'parser ' .. parser .. ': not installed') end
end
local junit_jar = require('neotest-java.default_config').junit_jar:to_string()
if not vim.uv.fs_stat(junit_jar) then table.insert(wrong, 'neotest-java: no ' .. junit_jar) end
if #wrong > 0 then return fail('not as pinned (see :Mason / :checkhealth nvim-treesitter in the e2e env):\n  ' .. table.concat(wrong, '\n  ')) end
vim.cmd 'qall!'
