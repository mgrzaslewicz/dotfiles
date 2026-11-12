local workspace_symbols = require 'custom.workspace_symbols'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['query: an empty or blank prompt sends no request'] = function()
  eq(workspace_symbols.query '', nil)
  eq(workspace_symbols.query '   ', nil)
end

T['title: names the 3-character minimum in the picker title and the gW menu'] = function()
  eq(workspace_symbols.title 'Workspace Symbols', 'Workspace Symbols (type 3+ characters)')
end

T['query: a single word is the query'] = function() eq(workspace_symbols.query 'stream', 'stream') end

T['query: the first word with an uppercase letter wins over the package'] = function()
  eq(workspace_symbols.query 'java.io InputStream', 'InputStream')
  eq(workspace_symbols.query 'io Input', 'Input')
end

T['query: a word under 3 characters sends no request'] = function()
  eq(workspace_symbols.query 'S', nil)
  eq(workspace_symbols.query 'java.io Ins', 'Ins')
  eq(workspace_symbols.query 'Sc', nil)
  eq(workspace_symbols.query 'Sco', 'Sco')
end

T['query: without an uppercase word, the last word'] = function() eq(workspace_symbols.query 'java ios', 'ios') end

T['symbol_width: the default 25 columns when the names are short'] = function()
  eq(workspace_symbols.symbol_width({ { text = '[Class] Foo' } }, 200), 25)
  eq(workspace_symbols.symbol_width({}, 200), 25)
end

T['symbol_width: the longest name in the results, without its kind'] = function()
  local long = ('a'):rep(60)
  eq(workspace_symbols.symbol_width({ { text = '[Method] run' }, { text = '[Class] ' .. long } }, 200), 60)
  eq(workspace_symbols.symbol_width({ { text = '[Method] ' .. long } }, 200), 60)
end

T['symbol_width: capped at 40% of the window so the path and type stay visible'] = function()
  local long = ('a'):rep(60)
  eq(workspace_symbols.symbol_width({ { text = '[Class] ' .. long } }, 100), 40)
end

return T
