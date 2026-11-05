-- `gry`: the fully qualified reference of the declaration around the cursor to the clipboard (IntelliJ Copy Reference).
-- Pure formatting in custom.copy_reference; the keymap is checked in a child nvim with a fake server.
local helpers = require 'tests.helpers'
local reference = require('custom.copy_reference').reference
local eq = MiniTest.expect.equality

local function span(sl, sc, el, ec) return { start = { line = sl, character = sc }, ['end'] = { line = el, character = ec } } end

local function sym(name, kind, range, children) return { name = name, kind = kind, range = range, selectionRange = range, children = children } end

local CLASS, METHOD, FIELD, FUNCTION, OBJECT = 5, 6, 8, 12, 19

-- package com.example.app      (line 0)
-- class Outer {                (2..12)
--   val name = ""              (3)
--   fun run() { ... }          (4..6)
--   class Inner { fun go() }   (8..10)
-- }
-- object Registry { }          (13..14)
-- fun main() {}                (16)
local symbols = {
  sym('Outer', CLASS, span(2, 0, 12, 1), {
    sym('name', FIELD, span(3, 2, 3, 15)),
    sym('run()', METHOD, span(4, 2, 6, 3)),
    sym('Inner', CLASS, span(8, 2, 10, 3), { sym('go', METHOD, span(9, 4, 9, 15)) }),
  }),
  sym('Registry', OBJECT, span(13, 0, 14, 1)),
  sym('main', FUNCTION, span(16, 0, 16, 13)),
}
local lines = { 'package com.example.app;' }

local function at(line, character) return { line = line, character = character } end

local T = MiniTest.new_set()

T['reference()'] = MiniTest.new_set()

T['reference()']['is the class with a member after #, the method without its signature'] = function()
  eq(reference(lines, symbols, at(5, 4)), 'com.example.app.Outer#run')
  eq(reference(lines, symbols, at(3, 6)), 'com.example.app.Outer#name')
end

T['reference()']['joins nested classes and Kotlin objects with dots'] = function()
  eq(reference(lines, symbols, at(9, 8)), 'com.example.app.Outer.Inner#go')
  eq(reference(lines, symbols, at(8, 2)), 'com.example.app.Outer.Inner')
  eq(reference(lines, symbols, at(13, 3)), 'com.example.app.Registry')
end

T['reference()']['joins a top-level function to the package with a dot'] = function() eq(reference(lines, symbols, at(16, 5)), 'com.example.app.main') end

T['reference()']['is the class on its header and between members'] = function()
  eq(reference(lines, symbols, at(2, 7)), 'com.example.app.Outer')
  eq(reference(lines, symbols, at(7, 0)), 'com.example.app.Outer')
end

T['reference()']['has no package in a file without one, and is nil outside every declaration'] = function()
  eq(reference({ 'import foo' }, symbols, at(5, 4)), 'Outer#run')
  eq(reference(lines, symbols, at(1, 0)), nil)
end

local child = helpers.new_child()

T['gry'] = MiniTest.new_set {
  hooks = {
    pre_case = function()
      -- The test child has no clipboard tool: a provider that keeps `+` in memory.
      child.start {
        '--cmd',
        "lua vim.g.clipboard = { name = 'test', copy = { ['+'] = function(l) _G.clip = l end, ['*'] = function(l) _G.clip = l end }, "
          .. "paste = { ['+'] = function() return _G.clip or {} end, ['*'] = function() return _G.clip or {} end } }",
      }
      local root = helpers.tree { ['Foo.kt'] = 'package com.example\n\nclass Foo {\n  fun run() {}\n}\n' }
      child.cmd('cd ' .. root)
      child.cmd 'edit Foo.kt'
      child.lua [=[
        local function span(sl, sc, el, ec) return { start = { line = sl, character = sc }, ['end'] = { line = el, character = ec } } end
        _G.fake_handlers = {
          ['textDocument/documentSymbol'] = function()
            local run = { name = 'run', kind = 6, range = span(3, 2, 3, 14), selectionRange = span(3, 6, 3, 9) }
            return { { name = 'Foo', kind = 5, range = span(2, 0, 4, 1), selectionRange = span(2, 6, 2, 9), children = { run } } }
          end,
        }
      ]=]
      helpers.start_fake_server(child, { documentSymbolProvider = true })
    end,
    post_case = function() child.stop() end,
  },
}

T['gry']['copies the reference of the method under the cursor to the clipboard'] = function()
  child.lua [=[ vim.api.nvim_win_set_cursor(0, { 4, 7 }) ]=]
  child.type_keys 'gry'
  child.lua [=[ vim.wait(2000, function() return vim.fn.getreg('+') ~= '' end) ]=]
  eq(child.lua_get "vim.fn.getreg('+')", 'com.example.Foo#run')
end

T['gry']['copies the file and line outside every declaration'] = function()
  child.lua [=[ vim.api.nvim_win_set_cursor(0, { 2, 0 }) ]=]
  child.type_keys 'gry'
  child.lua [=[ vim.wait(2000, function() return vim.fn.getreg('+') ~= '' end) ]=]
  eq(child.lua_get "vim.fn.getreg('+')", 'Foo.kt:2')
end

return T
