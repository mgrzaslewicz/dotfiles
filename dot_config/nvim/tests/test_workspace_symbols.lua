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

return T
