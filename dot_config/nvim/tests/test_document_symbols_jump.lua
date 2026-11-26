-- `]o` / `[o`: the next or previous document symbol (what `gO` lists), nested ones included. Pure choice of target in
-- custom.document_symbols; the keymaps are checked in a child nvim with a fake server.
local helpers = require 'tests.helpers'
local target = require('custom.document_symbols').target
local eq = MiniTest.expect.equality

local function at(line, character) return { line = line, character = character } end

local function range(line, character) return { start = at(line, character), ['end'] = at(line, character + 3) } end

-- A class at line 0 (name at 0:6) with two methods; a top-level function. Unsorted on purpose.
local function sym(name, line, character, children)
  return { name = name, range = range(line, 0), selectionRange = range(line, character), children = children }
end
local symbols = { sym('top', 9, 4), sym('Foo', 0, 6, { sym('b', 5, 6), sym('a', 2, 6) }) }

local T = MiniTest.new_set()

T['target()'] = MiniTest.new_set()

T['target()']['is the next symbol name after the cursor, children included'] = function()
  eq(target(symbols, at(0, 6), 1), at(2, 6))
  eq(target(symbols, at(3, 0), 1), at(5, 6))
end

T['target()']['is the previous symbol name, skipping the one under the cursor'] = function()
  eq(target(symbols, at(5, 7), -1), at(2, 6))
  eq(target(symbols, at(4, 0), -1), at(2, 6))
end

T['target()']['wraps around the ends of the buffer'] = function()
  eq(target(symbols, at(9, 4), 1), at(0, 6))
  eq(target(symbols, at(0, 6), -1), at(9, 4))
end

T['target()']['moves count symbols'] = function() eq(target(symbols, at(0, 6), 2), at(5, 6)) end

T['target()']['takes SymbolInformation (flat, location) too'] = function()
  local flat = { { name = 'x', location = { uri = 'file:///x', range = range(3, 2) } } }
  eq(target(flat, at(0, 0), 1), at(3, 2))
end

T['target()']['is nil without symbols'] = function() eq(target({}, at(0, 0), 1), nil) end

local child = helpers.new_child()

T[']o and [o'] = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.start()
      local root = helpers.tree { ['Foo.kt'] = 'class Foo {\n\n  fun a() {}\n\n\n  fun b() {}\n}\n\n\nfun top() {}\n' }
      child.cmd('edit ' .. root .. '/Foo.kt')
      child.lua [=[
        local function r(l, c) return { start = { line = l, character = c }, ['end'] = { line = l, character = c + 3 } } end
        local function s(n, l, c, ch) return { name = n, kind = 12, range = r(l, 0), selectionRange = r(l, c), children = ch } end
        _G.fake_handlers = { ['textDocument/documentSymbol'] = function() return { s('top', 9, 4), s('Foo', 0, 6, { s('b', 5, 6), s('a', 2, 6) }) } end }
      ]=]
      helpers.start_fake_server(child, { documentSymbolProvider = true })
      child.lua [=[ vim.api.nvim_win_set_cursor(0, { 1, 6 }) ]=]
    end,
    post_case = function() child.stop() end,
  },
}

local function press(keys, row, col)
  child.type_keys(keys)
  child.lua(('vim.wait(2000, function() local c = vim.api.nvim_win_get_cursor(0) return c[1] == %d and c[2] == %d end)'):format(row, col))
  eq(child.lua_get 'vim.api.nvim_win_get_cursor(0)', { row, col })
end

T[']o and [o']['jump between the symbols in the buffer, wrapping around'] = function()
  press(']o', 3, 6)
  press(']o', 6, 6)
  press(']o', 10, 4)
  press(']o', 1, 6)
  press('[o', 10, 4)
end

T[']o and [o']['take a count'] = function() press('2]o', 6, 6) end

return T
