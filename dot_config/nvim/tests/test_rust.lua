-- Rust: rust_analyzer (Mason) is enabled; codelldb (Mason) debugs a binary cargo builds. Unit tests cover the Cargo.toml reading; the rest checks the wiring without a server or adapter (layer B).
local helpers = require 'tests.helpers'
local package_name = require('custom.rust').package_name
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['package_name()'] = MiniTest.new_set()

T['package_name()']['is the name in [package]'] = function() eq(package_name '[package]\nname = "app"\nversion = "0.1.0"\n', 'app') end

T['package_name()']['ignores name keys of other tables'] = function() eq(package_name '[dependencies]\nname = "x"\n\n[package]\nname = "app"\n', 'app') end

T['package_name()']['reads past [[bin]] tables'] = function()
  eq(package_name '[package]\nname = "app"\n\n[[bin]]\nname = "tool"\npath = "src/tool.rs"\n', 'app')
end

T['package_name()']['is nil for a virtual workspace manifest'] = function() eq(package_name '[workspace]\nmembers = ["app"]\n', nil) end

local child = helpers.new_child()

local lsp = MiniTest.new_set {
  hooks = {
    pre_case = function() child.start() end,
    post_case = function() child.stop() end,
  },
}

lsp['rust_analyzer is enabled'] = function() eq(child.lua_get [[vim.lsp.is_enabled 'rust_analyzer']], true) end

T['debug'] = MiniTest.new_set {
  hooks = {
    pre_case = function() child.start() end,
    post_case = function() child.stop() end,
  },
}

T['debug']['codelldb adapter is registered'] = function() eq(child.lua_get [[require('dap').adapters.codelldb.type]], 'server') end

T['debug']['Rust launch asks for the binary of the package, defaulting to target/debug/<package>'] = function()
  local dir = helpers.tree {
    ['Cargo.toml'] = '[package]\nname = "app"\n',
    ['src/main.rs'] = 'fn main() {}\n',
  }
  child.cmd('edit ' .. dir .. '/src/main.rs')
  local prompt = child.lua [=[
    local prompt
    vim.fn.input = function(text, default) prompt = { text, default } return default end
    local config = require('dap').configurations.rust[1]
    local program = config.program()
    return { prompt, program }
  ]=]
  eq(prompt, { { 'Executable: ', dir .. '/target/debug/app' }, dir .. '/target/debug/app' })
end

T['debug']['Rust launch runs from the workspace folder'] = function() eq(child.lua_get [[require('dap').configurations.rust[1].cwd]], '${workspaceFolder}') end

T['lsp'] = lsp

return T
