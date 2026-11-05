-- `]r` / `[r`: the next or previous usage, in the buffer, of the symbol under the cursor (the server's document
-- highlights). Pure choice of target in custom.usages; the keymaps are checked in a child nvim with a fake server.
local helpers = require 'tests.helpers'
local target = require('custom.usages').target
local eq = MiniTest.expect.equality

local function at(line, character) return { line = line, character = character } end

local function hl(line, character) return { range = { start = at(line, character), ['end'] = at(line, character + 3) } } end

-- Unsorted on purpose: servers do not promise an order.
local highlights = { hl(5, 0), hl(0, 4), hl(2, 8) }

local T = MiniTest.new_set()

T['target()'] = MiniTest.new_set()

T['target()']['is the next usage after the cursor, from inside a usage or between them'] = function()
  eq(target(highlights, at(0, 5), 1), at(2, 8))
  eq(target(highlights, at(1, 0), 1), at(2, 8))
end

T['target()']['is the previous usage, skipping the one under the cursor'] = function()
  eq(target(highlights, at(2, 9), -1), at(0, 4))
  eq(target(highlights, at(4, 0), -1), at(2, 8))
end

T['target()']['wraps around the ends of the buffer'] = function()
  eq(target(highlights, at(5, 1), 1), at(0, 4))
  eq(target(highlights, at(0, 4), -1), at(5, 0))
end

T['target()']['moves count usages'] = function()
  eq(target(highlights, at(0, 4), 2), at(5, 0))
  eq(target(highlights, at(0, 4), -2), at(2, 8))
end

T['target()']['is nil without usages'] = function() eq(target({}, at(0, 0), 1), nil) end

local child = helpers.new_child()

T[']r and [r'] = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.start()
      local root = helpers.tree { ['Foo.kt'] = 'val foo = 1\n\nval bar = foo\n\n\nfoo + 1\n' }
      child.cmd('edit ' .. root .. '/Foo.kt')
      child.lua [=[
        local function hl(l, c) return { range = { start = { line = l, character = c }, ['end'] = { line = l, character = c + 3 } } } end
        _G.fake_handlers = { ['textDocument/documentHighlight'] = function() return { hl(5, 0), hl(0, 4), hl(2, 10) } end }
      ]=]
      helpers.start_fake_server(child, { documentHighlightProvider = true })
      child.lua [=[ vim.api.nvim_win_set_cursor(0, { 1, 4 }) ]=]
    end,
    post_case = function() child.stop() end,
  },
}

local function press(keys, row, col)
  child.type_keys(keys)
  child.lua(('vim.wait(2000, function() local c = vim.api.nvim_win_get_cursor(0) return c[1] == %d and c[2] == %d end)'):format(row, col))
  eq(child.lua_get 'vim.api.nvim_win_get_cursor(0)', { row, col })
end

T[']r and [r']['jump between the usages in the buffer, wrapping around'] = function()
  press(']r', 3, 10)
  press(']r', 6, 0)
  press(']r', 1, 4)
  press('[r', 6, 0)
end

T[']r and [r']['take a count'] = function() press('2]r', 6, 0) end

return T
