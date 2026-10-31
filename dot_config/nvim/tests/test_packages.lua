local packages = require 'custom.packages'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local tools_text = table.concat({
  'M.mason = {',
  '  -- Python, started by enabling `pyright` in `servers` (init.lua).',
  "  { 'pyright', version = '1.1.414' },",
  "  { 'kotlin-lsp', version = 'kotlin-lsp/v263.7084.0' },",
  '}',
  '',
}, '\n')

T['set_pin changes only the named version'] = function()
  local expected = tools_text:gsub("'1%.1%.414'", "'1.2.0'")
  eq(packages.set_pin(tools_text, 'pyright', '1.2.0'), expected)
end

T['set_pin keeps a name that is a prefix of another'] = function()
  local text = "  { 'kotlin', version = '1' },\n  { 'kotlin-lsp', version = '2' },\n"
  eq(packages.set_pin(text, 'kotlin', '3'), "  { 'kotlin', version = '3' },\n  { 'kotlin-lsp', version = '2' },\n")
end

T['set_pin refuses an unknown tool'] = function() eq(pcall(packages.set_pin, tools_text, 'nope', '1.0.0'), false) end

T['is_major flags a changed major, or a changed minor below 1.0'] = function()
  eq(packages.is_major('v1.63.0', 'v2.0.0'), true)
  eq(packages.is_major('0.4.4', '0.5.0'), true)
  eq(packages.is_major('1.1.414', '1.2.0'), false)
  eq(packages.is_major('0.4.4', '0.4.5'), false)
  eq(packages.is_major('v2.6.0', 'v2.7.1'), false)
end

T['pin_changes lists only pins whose version moved'] = function()
  local old = { { 'pyright', version = '1.1.414' }, { 'stylua', version = 'v2.6.0' } }
  local new = { { 'pyright', version = '2.0.0' }, { 'stylua', version = 'v2.6.0' } }
  eq(packages.pin_changes(old, new), { { name = 'pyright', from = '1.1.414', to = '2.0.0', major = true } })
end

T['plugin_changes lists moved and new revisions, sorted by name'] = function()
  local old = { LuaSnip = { rev = 'aaaaaaaa11' }, ['blink.cmp'] = { rev = 'bbbbbbbb22' } }
  local new = { LuaSnip = { rev = 'cccccccc33' }, ['blink.cmp'] = { rev = 'bbbbbbbb22' }, ['new.nvim'] = { rev = 'dddddddd44' } }
  eq(packages.plugin_changes(old, new), {
    { name = 'LuaSnip', from = 'aaaaaaaa11', to = 'cccccccc33' },
    { name = 'new.nvim', from = nil, to = 'dddddddd44' },
  })
end

T['report writes one line per change, short revisions, major flagged'] = function()
  local body = packages.report(
    { { name = 'jdtls', from = 'v1.63.0', to = 'v2.0.0', major = true } },
    { { name = 'LuaSnip', from = 'aaaaaaaa11', to = 'cccccccc33' }, { name = 'new.nvim', to = 'dddddddd44' } }
  )
  eq(
    body,
    table.concat({
      '- plugin LuaSnip: aaaaaaaa → cccccccc',
      '- plugin new.nvim: new → dddddddd',
      '- mason jdtls: v1.63.0 → v2.0.0 (major)',
    }, '\n')
  )
end

return T
