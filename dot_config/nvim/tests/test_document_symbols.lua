local document_symbols = require 'custom.document_symbols'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['symbol_width: the default 25 columns when the names are short'] = function()
  eq(document_symbols.symbol_width({ 'run', 'Foo' }, 200), 25)
  eq(document_symbols.symbol_width({}, 200), 25)
end

T['symbol_width: the longest name when it fits in the window'] = function()
  local long = ('a'):rep(60)
  eq(document_symbols.symbol_width({ 'run', long }, 200), 60)
end

T['symbol_width: capped at 40% of the window so the type and preview stay visible'] = function()
  local long = ('a'):rep(60)
  eq(document_symbols.symbol_width({ long }, 100), 40)
end

return T
