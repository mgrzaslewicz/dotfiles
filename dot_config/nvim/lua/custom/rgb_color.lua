-- CSS-style `rgb(r, g, b)` / `rgba(...)` colors shown in their own color by mini.hipatterns.
--
-- Channels are 0-255 integers, comma or space separated; an alpha (`, 0.5` or `/ 50%`) is accepted and ignored.
-- Percentage channels are not recognized.
local M = {}

--- `#rrggbb` of an `rgb(...)` / `rgba(...)` text, nil when it is not a color.
---@param text string
---@return string?
function M.hex(text)
  local r, g, b, alpha = text:match '^rgba?%(%s*(%d+)%s*[,%s]%s*(%d+)%s*[,%s]%s*(%d+)%s*(.-)%)$'
  if not r or (alpha ~= '' and not alpha:match '^[,/]%s*[%d.]+%%?%s*$') then return nil end
  local channels = { tonumber(r), tonumber(g), tonumber(b) }
  for _, channel in ipairs(channels) do
    if channel > 255 then return nil end
  end
  return string.format('#%02x%02x%02x', unpack(channels))
end

--- mini.hipatterns highlighter for `rgb(...)` / `rgba(...)`.
function M.highlighter()
  return {
    pattern = '%f[%w]rgba?%b()',
    group = function(_, match)
      local hex = M.hex(match)
      return hex and require('mini.hipatterns').compute_hex_color_group(hex, 'bg')
    end,
  }
end

return M
