-- 256-color terminal palette names (tmux `colour247` / `color247`) shown in their own color by mini.hipatterns.
--
-- Colors 0-15 are whatever the terminal theme says; the xterm defaults stand in for them here.
local M = {}

local system = {
  '000000',
  'cd0000',
  '00cd00',
  'cdcd00',
  '0000ee',
  'cd00cd',
  '00cdcd',
  'e5e5e5',
  '7f7f7f',
  'ff0000',
  '00ff00',
  'ffff00',
  '5c5cff',
  'ff00ff',
  '00ffff',
  'ffffff',
}
local cube_levels = { 0, 95, 135, 175, 215, 255 }

--- `#rrggbb` of palette color `n`, nil outside 0-255.
---@param n integer
---@return string?
function M.hex(n)
  if n < 16 then return n >= 0 and '#' .. system[n + 1] or nil end
  if n < 232 then
    local i = n - 16
    return string.format('#%02x%02x%02x', cube_levels[math.floor(i / 36) + 1], cube_levels[math.floor(i / 6) % 6 + 1], cube_levels[i % 6 + 1])
  end
  if n < 256 then
    local gray = 8 + 10 * (n - 232)
    return string.format('#%02x%02x%02x', gray, gray, gray)
  end
end

--- mini.hipatterns highlighter for `colourN` / `colorN` words.
function M.highlighter()
  return {
    pattern = '%f[%w]colou?r%d+%f[%W]',
    group = function(_, match)
      local hex = M.hex(tonumber(match:match '%d+') --[[@as integer]])
      return hex and require('mini.hipatterns').compute_hex_color_group(hex, 'bg')
    end,
  }
end

return M
