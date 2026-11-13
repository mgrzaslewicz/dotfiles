local parsers = require 'custom.parsers'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['missing lists the wanted parsers that are not built, in order'] = function()
  eq(parsers.missing({ 'bash', 'java', 'lua' }, { 'lua', 'vim' }), { 'bash', 'java' })
end

T['missing is empty when every wanted parser is built'] = function() eq(parsers.missing({ 'bash' }, { 'bash', 'lua' }), {}) end

return T
