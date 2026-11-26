-- Document symbols picker for `gO`. Telescope's `lsp_document_symbols` gives the symbol name a fixed 25 columns, so
-- long names (jdtls signatures, Kotlin generics) are cut short even when the window has room. Here the name column
-- is sized to the longest name, capped at 40% of the window so the type and the preview keep their space.
-- Tests: tests/test_document_symbols.lua.

local M = {}

-- Telescope's own default for the name column; the minimum here, so short names keep the usual layout.
local MIN_WIDTH = 25

--- Width of the symbol name column: the longest of `names`, between MIN_WIDTH and 40% of `columns`.
---@param names string[]
---@param columns integer width of the editor in columns
---@return integer
function M.symbol_width(names, columns)
  local longest = MIN_WIDTH
  for _, name in ipairs(names) do
    longest = math.max(longest, vim.fn.strdisplaywidth(name))
  end
  return math.min(longest, math.max(MIN_WIDTH, math.floor(columns * 0.4)))
end

--- Names of a documentSymbol tree, children included.
---@param symbols table[]
---@param names? string[]
---@return string[]
local function collect_names(symbols, names)
  names = names or {}
  for _, sym in ipairs(symbols) do
    table.insert(names, sym.name)
    collect_names(sym.children or {}, names)
  end
  return names
end

--- `a` before `b`, both `{ line, character }`.
local function before(a, b) return a.line < b.line or (a.line == b.line and a.character < b.character) end

--- Every symbol of a documentSymbol tree (children included) or a flat SymbolInformation list, as `{ start, finish }`
--- of its name (selectionRange, or the location's range for SymbolInformation).
---@param symbols table[]
---@param out? table[]
---@return table[]
local function flatten(symbols, out)
  out = out or {}
  for _, sym in ipairs(symbols) do
    local range = sym.location and sym.location.range or sym.selectionRange
    table.insert(out, { start = range.start, finish = range['end'] })
    if not sym.location then flatten(sym.children or {}, out) end
  end
  return out
end

--- The symbol `delta` steps from `pos` (0-based `{ line, character }`) in document order, wrapping around the buffer.
--- Positive counts forward from the cursor; negative backward, skipping the symbol the cursor is in.
---@param symbols table[] documentSymbol tree or SymbolInformation list
---@param pos { line: integer, character: integer }
---@param delta integer
---@return { line: integer, character: integer }|nil nil without symbols
function M.target(symbols, pos, delta)
  local list = flatten(symbols)
  local n = #list
  if n == 0 then return nil end
  table.sort(list, function(a, b) return before(a.start, b.start) end)

  local at_or_before, before_pos = 0, 0
  for _, sym in ipairs(list) do
    if not before(pos, sym.start) then at_or_before = at_or_before + 1 end
    if before(sym.start, pos) then before_pos = before_pos + 1 end
  end

  local index -- 0-based
  if delta > 0 then
    index = at_or_before - 1 + delta
  else
    local last = before_pos - 1 -- last symbol starting before the cursor
    local under = last >= 0 and not before(pos, list[last + 1].start) and before(pos, list[last + 1].finish)
    if under then last = last - 1 end
    index = last + delta + 1
  end

  local sym = list[(index % n) + 1].start
  return { line = sym.line, character = sym.character }
end

--- Moves the cursor `delta` document symbols away (`]o` / `[o`); the request is made from the cursor as it is now.
---@param delta integer
function M.jump(delta)
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local pos = { line = cursor[1] - 1, character = cursor[2] }
  require('custom.implementations').request_all('textDocument/documentSymbol', { textDocument = vim.lsp.util.make_text_document_params(buf) }, function(symbols)
    local to = M.target(symbols, pos, delta)
    if to then vim.api.nvim_win_set_cursor(0, { to.line + 1, to.character }) end
  end, buf)
end

--- Opens the document symbols of the current buffer in a Telescope picker, the name column sized to fit them.
function M.picker()
  local buf = vim.api.nvim_get_current_buf()
  require('custom.implementations').request_all('textDocument/documentSymbol', { textDocument = vim.lsp.util.make_text_document_params(buf) }, function(symbols)
    local width = M.symbol_width(collect_names(symbols), vim.o.columns)
    require('telescope.builtin').lsp_document_symbols { symbol_width = width }
  end, buf)
end

return M
