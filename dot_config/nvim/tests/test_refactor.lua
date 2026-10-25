local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.start()
      helpers.attach_fake_lsp(child)
    end,
    post_case = function() child.stop() end,
  },
}

T['maps refactor actions under <leader>r in LSP buffers'] = function()
  local maps = child.lua [=[
    local ret = {}
    for _, m in ipairs { { 'n', 'n' }, { 'n', 'o' }, { 'n', 'v' }, { 'x', 'v' }, { 'n', 'V' }, { 'n', 'c' }, { 'x', 'c' }, { 'x', 'm' } } do
      local map = vim.fn.maparg(' r' .. m[2], m[1], false, true)
      ret[m[1] .. m[2]] = map.buffer == 1 and map.desc
    end
    return ret
  ]=]
  eq(maps, {
    nn = 'Refactor: Re[n]ame',
    no = 'Refactor: [O]rganize imports',
    nv = 'Refactor: Extract [V]ariable',
    xv = 'Refactor: Extract [V]ariable',
    nV = 'Refactor: Extract [V]ariable (all occurrences)',
    nc = 'Refactor: Extract [C]onstant',
    xc = 'Refactor: Extract [C]onstant',
    xm = 'Refactor: Extract [M]ethod',
  })
end

-- Servers return every extract action for the cursor; the title decides which one a key applies.
local function applied(keys, offered)
  child.lua('_G.offered = ...', { offered })
  child.type_keys(keys)
  child.lua 'vim.wait(2000, function() return #_G.applied > 0 end)'
  return child.lua_get '_G.applied'
end

T['extract variable applies the server action titled "variable", case-insensitively'] = function()
  eq(applied(' rv', { 'Extract method', 'Introduce local Variable', 'Extract constant' }), { 'Introduce local Variable' })
end

T['extract method also matches "function" titles'] = function()
  eq(applied({ 'V', ' rm' }, { 'Extract to variable', 'Extract to function in module scope' }), { 'Extract to function in module scope' })
end

T['extract variable (all occurrences) does not apply the single-occurrence action'] = function()
  eq(applied(' rV', { 'Extract variable', 'Extract variable (replace all occurrences)' }), { 'Extract variable (replace all occurrences)' })
end

T['nothing is applied when no title matches'] = function()
  child.lua('_G.offered = ...', { { 'Extract method' } })
  child.type_keys ' rc'
  child.lua 'vim.wait(300)'
  eq(child.lua_get '_G.applied', {})
end

T['a registered handler replaces the default and learns about visual mode'] = function()
  child.lua [[
    _G.calls = {}
    require('custom.refactor').register(0, { extract_variable = function(visual) table.insert(_G.calls, visual) end })
  ]]
  child.type_keys ' rv'
  child.type_keys('<Esc>', 'v', ' rv')
  eq(child.lua_get '_G.calls', { false, true })
  eq(child.lua_get '_G.applied', {})
end

-- nvim-jdtls reads the selection from the '< and '> marks, which Vim sets only when visual mode ends.
T['a registered handler called from visual mode sees the current selection in its marks'] = function()
  child.lua [[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one two three', 'four five six' })
    require('custom.refactor').register(0, {
      extract_method = function() _G.seen = { vim.fn.mode(), vim.api.nvim_buf_get_mark(0, '<'), vim.api.nvim_buf_get_mark(0, '>') } end,
    })
  ]]
  child.type_keys('2G', 'v', 'e', '<Esc>') -- an older selection: "four"
  child.type_keys('gg', 'w', 'v', 'e', ' rm') -- "two"
  eq(child.lua_get '_G.seen', { 'n', { 1, 4 }, { 1, 6 } })
end

T['the default code action gets the visual selection as its range'] = function()
  child.lua "vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one two three', 'four five six' })"
  child.type_keys('2G', 'v', 'e', '<Esc>')
  child.lua('_G.offered = ...', { { 'Extract variable' } })
  child.type_keys('gg', 'w', 'v', 'e', ' rv')
  child.lua 'vim.wait(2000, function() return #_G.applied > 0 end)'
  eq(child.lua_get '_G.code_action_range', { start = { line = 0, character = 4 }, ['end'] = { line = 0, character = 7 } })
end

return T
