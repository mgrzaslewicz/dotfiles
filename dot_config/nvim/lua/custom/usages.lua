-- `]r` / `[r`: next / previous usage, in the buffer, of the symbol under the cursor (IntelliJ highlight usages, then
-- F3 / Shift+F3). The usages are the server's document highlights (textDocument/documentHighlight), the ones shown on
-- CursorHold; the jump wraps around the ends of the buffer and takes a count. Language-agnostic.
-- Tests: tests/test_usages.lua.

local M = {}

local contains = require('custom.implementations').contains

local function before(a, b) return a.line < b.line or (a.line == b.line and a.character < b.character) end

--- The start of the usage `count` usages away from `pos` (forward when positive), wrapping around, or nil without
--- usages. Backward skips the usage `pos` is in.
---@param highlights {range: table}[] DocumentHighlight results, in any order
---@param pos {line: integer, character: integer} 0-based, utf-16
---@param count integer
---@return {line: integer, character: integer}?
function M.target(highlights, pos, count)
  if #highlights == 0 then return nil end
  local ranges = vim.tbl_map(function(h) return h.range end, highlights)
  table.sort(ranges, function(a, b) return before(a.start, b.start) end)
  for _ = 1, math.abs(count) do
    local found
    if count > 0 then
      for _, r in ipairs(ranges) do
        if before(pos, r.start) then
          found = r
          break
        end
      end
      found = found or ranges[1]
    else
      for i = #ranges, 1, -1 do
        if before(ranges[i].start, pos) and not contains(ranges[i], pos) then
          found = ranges[i]
          break
        end
      end
      found = found or ranges[#ranges]
    end
    pos = found.start
  end
  return pos
end

--- Moves the cursor `direction` (1 or -1) times the count usages away.
---@param direction integer
function M.jump(direction)
  local count = direction * vim.v.count1
  local win, bufnr = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  local params = vim.lsp.util.make_position_params(win, 'utf-16')
  require('custom.implementations').request_all('textDocument/documentHighlight', params, function(highlights)
    local pos = M.target(highlights, params.position, count)
    if not pos or not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= bufnr then return end
    local text = vim.api.nvim_buf_get_lines(bufnr, pos.line, pos.line + 1, false)[1] or ''
    vim.api.nvim_win_set_cursor(win, { pos.line + 1, vim.str_byteindex(text, 'utf-16', pos.character, false) })
  end)
end

return M
