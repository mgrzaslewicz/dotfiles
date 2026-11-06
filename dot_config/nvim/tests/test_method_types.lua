local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality
local method_types = require 'custom.method_types'

local function range(line, character) return { start = { line = line, character = character }, ['end'] = { line = line, character = character + 3 } } end

local function loc(uri, line, character) return { uri = uri, range = range(line, character) } end

local function names(ids)
  return vim.tbl_map(function(id) return id.name .. ':' .. id.group end, ids)
end

local T = MiniTest.new_set()

T['identifiers() lists the return type, then parameter types, then body identifiers, each name once (Kotlin)'] = function()
  local ids = method_types.identifiers({
    'fun publish(order: Order, items: List<Item>): Receipt {',
    '  val r = Repo.save(order)',
    '  return r.toReceipt()',
    '}',
  }, { line = 10, character = 0 }, { line = 10, character = 4 })
  eq(names(ids), {
    'Receipt:returns',
    'Order:params',
    'List:params',
    'Item:params',
    'r:body',
    'Repo:body',
    'save:body',
    'order:body',
    'toReceipt:body',
  })
end

T['identifiers() reads a Java header: annotations and modifiers skipped, generic and parameter types kept'] = function()
  local ids = method_types.identifiers({
    '@Override',
    'public List<Foo> find(Bar bar) {',
    '  return new Baz();',
    '}',
  }, { line = 0, character = 0 }, { line = 1, character = 17 })
  eq(names(ids), { 'List:returns', 'Foo:returns', 'Bar:params', 'bar:params', 'Baz:body' })
end

T['identifiers() takes the text after `=` of an expression body as the body'] = function()
  local ids = method_types.identifiers({ 'fun trimmed(text: String): String = text.trim()' }, { line = 0, character = 0 }, { line = 0, character = 4 })
  eq(names(ids), { 'String:returns', 'text:body', 'trim:body' })
end

T['identifiers() gives positions of each identifier, shifted by the origin on the first line'] = function()
  local ids = method_types.identifiers({ 'fun f(a: Order): Receipt {' }, { line = 5, character = 2 }, { line = 5, character = 6 })
  eq(ids[1], { name = 'Receipt', line = 5, character = 2 + 17, group = 'returns' })
  eq(ids[2], { name = 'Order', line = 5, character = 2 + 9, group = 'params' })
end

T['unique() keeps the first of the entries that share a file and declaration line'] = function()
  local a, b = 'file:///A.kt', 'file:///B.kt'
  eq(method_types.unique { loc(a, 3, 2), loc(a, 3, 6), loc(b, 3, 2), loc(a, 3, 2) }, { loc(a, 3, 2), loc(b, 3, 2) })
end

local child = helpers.new_child()

T['picker()'] = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.start()
      local file = helpers.tree {
        ['Foo.kt'] = 'class Foo {\n  fun publish(order: Order): Receipt {\n    return Receipt(order.total)\n  }\n}\n',
        ['Types.kt'] = 'class Order\nclass Receipt\n',
      }
      child.cmd('edit ' .. file .. '/Foo.kt')
      child.lua [=[
        -- Fake server. In Foo.kt: `Order` (1:21) and `Receipt` (1:29, 2:11) resolve to the classes in Types.kt; nothing
        -- else resolves. No type definitions. Symbols: class Foo with method publish; Types.kt declares Order and Receipt.
        local uri = vim.uri_from_bufnr(0)
        local types_uri = vim.uri_from_fname(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':h') .. '/Types.kt')
        local function span(sl, sc, el, ec) return { start = { line = sl, character = sc }, ['end'] = { line = el, character = ec } } end
        local order = { name = 'Order', kind = 5, range = span(0, 0, 0, 11), selectionRange = span(0, 6, 0, 11) }
        local receipt = { name = 'Receipt', kind = 5, range = span(1, 0, 1, 13), selectionRange = span(1, 6, 1, 13) }
        local foo = { name = 'Foo', kind = 5, range = span(0, 0, 4, 1), selectionRange = span(0, 6, 0, 9), children = {
          { name = 'publish', kind = 6, range = span(1, 2, 3, 3), selectionRange = span(1, 6, 1, 13) },
        } }
        local defs = {
          ['1:21'] = { uri = types_uri, range = order.selectionRange },
          ['1:29'] = { uri = types_uri, range = receipt.selectionRange },
          ['2:11'] = { uri = types_uri, range = receipt.selectionRange },
        }
        local symbols = { [uri] = { foo }, [types_uri] = { order, receipt } }
        vim.lsp.start {
          name = 'types',
          root_dir = vim.fn.getcwd(),
          cmd = function()
            local closing = false
            return {
              request = function(method, params, callback)
                local handlers = {
                  initialize = function() return { capabilities = { definitionProvider = true, typeDefinitionProvider = true, documentSymbolProvider = true } } end,
                  ['textDocument/definition'] = function()
                    local d = defs[params.position.line .. ':' .. params.position.character]
                    return d and { d } or {}
                  end,
                  ['textDocument/typeDefinition'] = function() return {} end,
                  ['textDocument/documentSymbol'] = function() return symbols[params.textDocument.uri] or {} end,
                }
                local result = handlers[method] and handlers[method]()
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
        vim.api.nvim_win_set_cursor(0, { 2, 8 })
      ]=]
    end,
    post_case = function() child.stop() end,
  },
}

T['picker()']['lists the return type, then the parameter types, in a picker titled after the method'] = function()
  child.lua [=[
    _G.picked = nil
    require('custom.implementations').pick = function(locations, title, keep_order) _G.picked = { locations = locations, title = title, keep_order = keep_order } end
    require('custom.method_types').picker()
    vim.wait(2000, function() return _G.picked ~= nil end)
  ]=]
  eq(child.lua_get '_G.picked.title', 'Types of publish')
  eq(child.lua_get '#_G.picked.locations', 2)
  eq(child.lua_get "vim.fn.fnamemodify(_G.picked.locations[1].uri, ':t')", 'Types.kt')
  eq(child.lua_get '_G.picked.locations[1].range.start.line', 1)
  eq(child.lua_get '_G.picked.locations[2].range.start.line', 0)
  eq(child.lua_get '_G.picked.keep_order', true)
end

T['picker()']['works with the cursor in the method body too'] = function()
  child.lua [=[
    vim.api.nvim_win_set_cursor(0, { 3, 4 })
    _G.picked = nil
    require('custom.implementations').pick = function(locations, title) _G.picked = { locations = locations, title = title } end
    require('custom.method_types').picker()
    vim.wait(2000, function() return _G.picked ~= nil end)
  ]=]
  eq(child.lua_get '#_G.picked.locations', 2)
end

T['picker()']['outside any method tells so and opens no picker'] = function()
  child.lua [=[
    _G.notified = nil
    _G.picked = nil
    vim.notify = function(msg) _G.notified = msg end
    require('custom.implementations').pick = function() _G.picked = true end
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    require('custom.method_types').picker()
    vim.wait(2000, function() return _G.notified ~= nil end)
  ]=]
  eq(child.lua_get '_G.notified', 'No method around the cursor')
  eq(child.lua_get '_G.picked', vim.NIL)
end

T['picker()']['grm is mapped in LSP buffers with its desc'] = function()
  eq(child.lua_get "vim.fn.maparg('grm', 'n', false, true).desc", '[G]oto [M]ethod types')
  eq(child.lua_get "vim.fn.maparg('grm', 'n', false, true).buffer", 1)
end

return T
