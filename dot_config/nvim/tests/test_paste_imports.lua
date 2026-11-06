local helpers = require 'tests.helpers'
local paste_imports = require 'custom.jvm.paste_imports'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set()

T['import_name() reads the type name from a jdtls import title'] = function()
  eq(paste_imports.import_name "Import 'List' (java.util)", 'List')
  eq(paste_imports.import_name "Import 'Map.Entry' (java.util)", 'Map.Entry')
end

T['import_name() reads the type name from a kotlin-lsp import title'] = function()
  eq(paste_imports.import_name "Import class 'Duration' → kotlin.time.Duration", 'Duration')
  eq(paste_imports.import_name "Import class 'Duration' → java.time.Duration", 'Duration')
end

T['import_name() is nil for titles that are not imports'] = function()
  eq(paste_imports.import_name 'Extract method', nil)
  eq(paste_imports.import_name 'Organize imports', nil)
end

T['group() keeps import actions and groups them by type name, sorted'] = function()
  local map = { title = "Import 'Map' (java.util)" }
  local list_util = { title = "Import 'List' (java.util)" }
  local list_awt = { title = "Import 'List' (java.awt)" }
  local extract = { title = 'Extract method' }
  eq(paste_imports.group { map, extract, list_util, list_awt }, {
    { name = 'List', actions = { list_util, list_awt } },
    { name = 'Map', actions = { map } },
  })
end

T['group() is empty when nothing is an import'] = function() eq(paste_imports.group { { title = 'Extract method' } }, {}) end

-- Real servers behind the paste hook are jdtls and kotlin_lsp. Here a fake server with one of those names answers code
-- actions from `_G.fake_handlers`. The hook is wired by LspAttach (init.lua calls setup), not by the test.
-- Pastes come from register `a`, so the test does not depend on the system clipboard.
local T_buffer = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.start()
      child.lua [[
        _G.applied = {}
        vim.lsp.commands['test.apply'] = function(cmd) table.insert(_G.applied, cmd.arguments[1]) end
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'class A {', '}' })
        vim.fn.setreg('a', { 'List<String> xs;', 'Map<K, V> m;' }, 'l')
      ]]
      helpers.start_fake_server(child, { codeActionProvider = true }, 'jdtls')
    end,
    post_case = function() child.stop() end,
  },
}

-- Makes the server offer `titles` as quick fixes, and records each code action request range in `_G.requests`.
local function offer(titles)
  child.lua(
    [=[
    local titles = ...
    _G.requests = {}
    _G.fake_handlers['textDocument/codeAction'] = function(params)
      table.insert(_G.requests, params.range)
      return vim.tbl_map(function(title)
        return { title = title, kind = 'quickfix', command = { title = title, command = 'test.apply', arguments = { title } } }
      end, titles)
    end
    ]=],
    { titles }
  )
end

-- Simulates the server publishing an unresolved reference on each 0-based line.
local function diagnose(lines)
  child.lua(
    [=[
    local lines = ...
    local diags = vim.tbl_map(function(lnum) return { lnum = lnum, col = 0, message = "Unresolved reference 'X'." } end, lines)
    vim.diagnostic.set(vim.api.nvim_create_namespace 'fake-server', 0, diags)
    ]=],
    { lines }
  )
end

local function wait_applied(count) child.lua(('vim.wait(2000, function() return #_G.applied >= %d end)'):format(count)) end

T_buffer['the hook is set on p and P in a jdtls or kotlin_lsp buffer'] = function()
  eq(child.lua_get "vim.fn.maparg('p', 'n', false, true).buffer", 1)
  eq(child.lua_get "vim.fn.maparg('P', 'n', false, true).buffer", 1)
end

T_buffer['"ap imports the types of the pasted lines'] = function()
  offer { "Import 'List' (java.util)" }
  child.type_keys '"ap'
  diagnose { 1, 2 }
  wait_applied(1)
  eq(child.lua_get 'vim.api.nvim_buf_get_lines(0, 0, -1, false)', { 'class A {', 'List<String> xs;', 'Map<K, V> m;', '}' })
  eq(child.lua_get '_G.requests', { { start = { line = 1, character = 0 }, ['end'] = { line = 3, character = 0 } } })
  eq(child.lua_get '_G.applied', { "Import 'List' (java.util)" })
end

T_buffer['"aP imports the types of the pasted lines too'] = function()
  offer { "Import 'Map' (java.util)" }
  child.type_keys 'gg"aP'
  diagnose { 0, 1 }
  wait_applied(1)
  eq(child.lua_get '_G.requests', { { start = { line = 0, character = 0 }, ['end'] = { line = 2, character = 0 } } })
  eq(child.lua_get '_G.applied', { "Import 'Map' (java.util)" })
end

T_buffer['imports every type that has one candidate'] = function()
  offer { "Import 'Map' (java.util)", "Import 'List' (java.util)" }
  child.type_keys '"ap'
  diagnose { 1, 2 }
  wait_applied(2)
  eq(child.lua_get '_G.applied', { "Import 'List' (java.util)", "Import 'Map' (java.util)" })
end

T_buffer['asks which package when a type has several candidates'] = function()
  offer { "Import 'List' (java.awt)", "Import 'List' (java.util)" }
  child.lua [[
    _G.picked = {}
    vim.ui.select = function(items, _, on_choice)
      _G.picked = items
      on_choice(items[2])
    end
  ]]
  child.type_keys '"ap'
  diagnose { 1 }
  wait_applied(1)
  eq(child.lua_get '_G.picked', { "Import 'List' (java.awt)", "Import 'List' (java.util)" })
  eq(child.lua_get '_G.applied', { "Import 'List' (java.util)" })
end

T_buffer['kotlin-lsp titles: picks among the packages of a class'] = function()
  child.lua [[
    for _, client in ipairs(vim.lsp.get_clients { bufnr = 0 }) do vim.lsp.stop_client(client.id, true) end
    vim.wait(2000, function() return #vim.lsp.get_clients { bufnr = 0 } == 0 end)
  ]]
  helpers.start_fake_server(child, { codeActionProvider = true }, 'kotlin_lsp')
  offer { "Import class 'Duration' → kotlin.time.Duration", "Import class 'Duration' → java.time.Duration" }
  child.lua [[
    vim.ui.select = function(items, _, on_choice) on_choice(items[1]) end
  ]]
  child.type_keys '"ap'
  diagnose { 1 }
  wait_applied(1)
  eq(child.lua_get '_G.applied', { "Import class 'Duration' → kotlin.time.Duration" })
end

T_buffer['does nothing when the server offers no import'] = function()
  offer { 'Extract method' }
  child.type_keys '"ap'
  diagnose { 1 }
  child.lua 'vim.wait(300)'
  eq(child.lua_get '_G.applied', {})
end

T_buffer['does not ask the server when the put lines have no diagnostic'] = function()
  child.lua 'require("custom.jvm.paste_imports").wait_ms = 300'
  offer { "Import 'List' (java.util)" }
  child.type_keys '"ap'
  child.lua 'vim.wait(600)'
  eq(child.lua_get '_G.requests', {})
  eq(child.lua_get '_G.applied', {})
end

T['in a buffer'] = T_buffer

return T
