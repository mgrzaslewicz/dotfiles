-- `<M-m>t`: the tests that call the method around the cursor or its family (lua/custom/method_tests.lua).
local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality
local method_tests = require 'custom.method_tests'

local T = MiniTest.new_set()

T['is_test_file()'] = MiniTest.new_set()

T['is_test_file()']['takes files in a test source set or named as a test'] = function()
  for _, path in ipairs {
    '/p/app/src/test/java/com/x/FooTest.java',
    '/p/app/src/test/kotlin/com/x/Helpers.kt',
    '/p/lib/src/integrationTest/kotlin/FooIT.kt',
    '/p/tests/test_foo.lua',
    '/p/pkg/foo_test.go',
    '/p/src/FooTests.kt',
    '/p/src/FooSpec.kt',
  } do
    eq({ path, method_tests.is_test_file(path) }, { path, true })
  end
end

T['is_test_file()']['leaves out main sources'] = function()
  for _, path in ipairs { '/p/app/src/main/java/com/x/Foo.java', '/p/app/src/main/kotlin/com/x/Testing.kt', '/p/lua/custom/latest.lua' } do
    eq({ path, method_tests.is_test_file(path) }, { path, false })
  end
end

local child = helpers.new_child()

-- A fake server for Foo.kt: `run` (lines 3-9) is called by `greets` in FooTest.kt (line 5), by `other` in the same
-- test file (line 9) and by `main` in Foo.kt (line 12); `Iface.run`, which `run` overrides, is called by `viaIface` in
-- IfaceTest.kt (line 3).
T['collect()'] = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.start()
      local dir = helpers.tree {
        ['src/main/Foo.kt'] = 'class Foo : Iface {\n\nfun run() {}' .. string.rep('\n', 12),
        ['src/main/Iface.kt'] = 'interface Iface {\nfun run()\n}',
        ['src/test/'] = '',
      }
      child.cmd('edit ' .. dir .. '/src/main/Foo.kt')
      child.lua [=[
        local function span(sl, sc, el, ec) return { start = { line = sl, character = sc }, ['end'] = { line = el, character = ec } } end
        local uri = vim.uri_from_bufnr(0)
        local root = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':h:h')
        local iface_uri = vim.uri_from_fname(root .. '/main/Iface.kt')
        _G.test_uri, _G.iface_test_uri = vim.uri_from_fname(root .. '/test/FooTest.kt'), vim.uri_from_fname(root .. '/test/IfaceTest.kt')
        local function method(name, line) return { name = name, kind = 6, range = span(line, 0, line + 2, 1), selectionRange = span(line, 4, line, 4 + #name) } end
        local symbols = {
          [uri] = { { name = 'Foo', kind = 5, range = span(0, 0, 14, 0), selectionRange = span(0, 6, 0, 9), children = { method('run', 2) } } },
          [iface_uri] = { { name = 'Iface', kind = 11, range = span(0, 0, 2, 1), selectionRange = span(0, 10, 0, 15), children = { method('run', 1) } } },
        }
        symbols[uri][1].children[1].range = span(2, 0, 8, 1)
        _G.overrides = true
        local callers = {
          [uri .. ':2'] = { { _G.test_uri, 'greets', 4 }, { uri, 'main', 11 }, { _G.test_uri, 'other', 8 } },
          [iface_uri .. ':1'] = { { _G.iface_test_uri, 'viaIface', 2 } },
        }
        vim.lsp.start {
          name = 'tests',
          root_dir = vim.fn.getcwd(),
          cmd = function()
            local closing = false
            return {
              request = function(m, params, callback)
                local handlers = {
                  initialize = function() return { capabilities = { implementationProvider = true, definitionProvider = true, documentSymbolProvider = true, callHierarchyProvider = true } } end,
                  ['textDocument/documentSymbol'] = function() return symbols[params.textDocument.uri] or {} end,
                  ['textDocument/definition'] = function() return _G.overrides and { { uri = iface_uri, range = span(0, 10, 0, 15) } } or {} end,
                  ['textDocument/implementation'] = function() return {} end,
                  ['textDocument/prepareCallHierarchy'] = function()
                    local p = params.position
                    return { { name = 'run', kind = 6, uri = params.textDocument.uri, range = span(p.line, 0, p.line, 9), selectionRange = span(p.line, p.character, p.line, p.character + 3) } }
                  end,
                  ['callHierarchy/incomingCalls'] = function()
                    local item = params.item
                    return vim.tbl_map(function(c)
                      local from = { name = c[2], kind = 6, uri = c[1], range = span(c[3], 0, c[3] + 2, 1), selectionRange = span(c[3], 4, c[3], 4 + #c[2]) }
                      return { from = from, fromRanges = { span(c[3] + 1, 2, c[3] + 1, 5) } }
                    end, callers[item.uri .. ':' .. item.selectionRange.start.line] or {})
                  end,
                }
                local result = handlers[m] and handlers[m]()
                vim.schedule(function() callback(nil, result) end)
                return true, 1
              end,
              notify = function() return true end,
              is_closing = function() return closing end,
              terminate = function() closing = true end,
            }
          end,
        }
        vim.wait(2000, function() return #vim.lsp.get_clients { bufnr = 0 } > 0 end)
        vim.api.nvim_win_set_cursor(0, { 6, 0 })
      ]=]
    end,
    post_case = function() child.stop() end,
  },
}

T['collect()']['lists the test methods calling the method or its supers, the method its own first'] = function()
  child.lua [=[
    _G.found = nil
    require('custom.method_tests').collect(function(tests, name) _G.found = { name = name, tests = tests } end)
    vim.wait(2000, function() return _G.found ~= nil end)
  ]=]
  eq(child.lua_get '_G.found.name', 'run')
  eq(child.lua_get 'vim.tbl_map(function(t) return { t.uri, t.name, t.range.start.line, t.range.start.character } end, _G.found.tests)', {
    { child.lua_get '_G.test_uri', 'greets', 4, 4 },
    { child.lua_get '_G.test_uri', 'other', 8, 4 },
    { child.lua_get '_G.iface_test_uri', 'viaIface', 2, 4 },
  })
end

T['collect()']['<M-m>t opens the tests in a picker, in that order'] = function()
  child.lua [=[
    _G.picked = nil
    require('custom.implementations').pick = function(locations, title, opts) _G.picked = { n = #locations, title = title, keep_order = opts and opts.keep_order } end
  ]=]
  child.type_keys '<M-m>t'
  child.lua [=[ vim.wait(2000, function() return _G.picked ~= nil end) ]=]
  eq(child.lua_get '_G.picked', { n = 3, title = 'Tests of run', keep_order = true })
end

T['collect()']['<M-m>t goes straight to the only test'] = function()
  child.lua [=[ _G.overrides = false ]=]
  child.lua [=[ require('custom.method_tests').collect = function(callback) callback({ { uri = _G.test_uri, range = { start = { line = 4, character = 4 }, ['end'] = { line = 4, character = 10 } } } }, 'run') end ]=]
  child.lua [=[ vim.fn.writefile({ '', '', '', '', '    greets' }, vim.uri_to_fname(_G.test_uri)) ]=]
  child.type_keys '<M-m>t'
  child.lua [=[ vim.wait(2000, function() return vim.api.nvim_buf_get_name(0):match('FooTest%.kt$') ~= nil end) ]=]
  eq({ child.lua_get "vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')", child.lua_get 'vim.api.nvim_win_get_cursor(0)' }, { 'FooTest.kt', { 5, 4 } })
end

T['collect()']['<M-m>t says so when no test calls the method'] = function()
  child.lua [=[ require('custom.method_tests').collect = function(callback) callback({}, 'run') end ]=]
  child.cmd 'messages clear'
  child.type_keys '<M-m>t'
  child.lua [=[ vim.wait(2000, function() return vim.fn.execute('messages'):match('No tests call run') ~= nil end) ]=]
  eq(child.lua_get "vim.fn.execute('messages'):match('No tests call run') ~= nil", true)
end

T['collect()']['<M-m>t is mapped in LSP buffers with its desc'] = function()
  eq(child.lua_get "vim.fn.maparg('<M-m>t', 'n', false, true).desc", 'Method: [T]ests')
end

return T
