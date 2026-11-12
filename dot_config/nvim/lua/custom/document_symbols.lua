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

--- Opens the document symbols of the current buffer in a Telescope picker, the name column sized to fit them.
function M.picker()
  local buf = vim.api.nvim_get_current_buf()
  require('custom.implementations').request_all('textDocument/documentSymbol', { textDocument = vim.lsp.util.make_text_document_params(buf) }, function(symbols)
    local width = M.symbol_width(collect_names(symbols), vim.o.columns)
    require('telescope.builtin').lsp_document_symbols { symbol_width = width }
  end, buf)
end

return M
