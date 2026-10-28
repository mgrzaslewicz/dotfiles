local term_colors = require 'custom.term_colors'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['system colors use xterm defaults'] = function()
  eq(term_colors.hex(0), '#000000')
  eq(term_colors.hex(1), '#cd0000')
  eq(term_colors.hex(15), '#ffffff')
end

T['6x6x6 color cube'] = function()
  eq(term_colors.hex(16), '#000000')
  eq(term_colors.hex(51), '#00ffff')
  eq(term_colors.hex(208), '#ff8700')
  eq(term_colors.hex(231), '#ffffff')
end

T['grayscale ramp'] = function()
  eq(term_colors.hex(232), '#080808')
  eq(term_colors.hex(247), '#9e9e9e')
  eq(term_colors.hex(255), '#eeeeee')
end

T['out of range is nil'] = function() eq(term_colors.hex(256), nil) end

return T
