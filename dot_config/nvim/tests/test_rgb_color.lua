local rgb_color = require 'custom.rgb_color'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['comma separated'] = function()
  eq(rgb_color.hex 'rgb(163,190,140)', '#a3be8c')
  eq(rgb_color.hex 'rgb( 163 , 190 , 140 )', '#a3be8c')
end

T['space separated'] = function() eq(rgb_color.hex 'rgb(163 190 140)', '#a3be8c') end

T['alpha is ignored'] = function()
  eq(rgb_color.hex 'rgba(163, 190, 140, 0.5)', '#a3be8c')
  eq(rgb_color.hex 'rgb(163 190 140 / 50%)', '#a3be8c')
end

T['not a color'] = function()
  eq(rgb_color.hex 'rgb(256, 0, 0)', nil)
  eq(rgb_color.hex 'rgb(1234)', nil)
  eq(rgb_color.hex 'rgb(1, 2)', nil)
  eq(rgb_color.hex 'rgb(1, 2, 3, x)', nil)
  eq(rgb_color.hex 'rgb(r, g, b)', nil)
end

return T
