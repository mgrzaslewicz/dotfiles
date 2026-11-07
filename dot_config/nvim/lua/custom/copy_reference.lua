-- Copy Reference (`gry`, IntelliJ Ctrl+Alt+Shift+C): the fully qualified name of the declaration around the cursor to
-- the clipboard, for test filters (`--tests`), logs and review comments. Language-agnostic: built from the server's
-- document symbols and the file's `package` line. Tests: tests/test_copy_reference.lua;
-- replayed on jdtls and kotlin-lsp in tests/test_replay_*.lua.
--
-- Format as IntelliJ's: classes (and Kotlin objects) joined by `.`, a member after `#` (`com.x.Outer.Inner#run`), a
-- top-level function after `.` (`com.x.main`). Method names lose their signature (jdtls names them `run(String)`).
-- Outside every declaration it is the file relative to the cwd and the line (`src/Foo.kt:12`).
--
-- Known limit: the reference is of the declaration around the cursor, not of a usage under it (a call of
-- `Other.run` inside `Foo.go` copies `Foo#go`).

local M = {}

local CLASS_KINDS = { [5] = true, [10] = true, [11] = true, [19] = true, [23] = true } -- class, enum, interface, object, struct

local contains = require('custom.implementations').contains

--- The reference of the declaration around `pos`, or nil outside every declaration.
---@param lines string[] the file's lines (only its `package` line is read)
---@param symbols table[] a documentSymbol tree
---@param pos {line: integer, character: integer} 0-based, utf-16
---@return string?
function M.reference(lines, symbols, pos)
  local package
  for _, line in ipairs(lines) do
    package = line:match '^%s*package%s+([%w_.]+)'
    if package then break end
  end
  local classes, member = {}, nil
  local level = symbols
  while level and not member do
    local inside
    for _, sym in ipairs(level) do
      if contains(sym.range, pos) then
        inside = sym
        break
      end
    end
    if not inside then break end
    local name = inside.name:match '^[^(%s]+' or inside.name
    if CLASS_KINDS[inside.kind] then
      table.insert(classes, name)
      level = inside.children
    else
      member = name
    end
  end
  if #classes == 0 and not member then return nil end
  local qualified = table.concat(vim.list_extend(package and { package } or {}, classes), '.')
  if not member then return qualified end
  if #classes == 0 then return qualified == '' and member or qualified .. '.' .. member end
  return qualified .. '#' .. member
end

--- Copies the reference of the declaration around the cursor to the clipboard (`+`) and echoes it.
function M.copy()
  local bufnr = vim.api.nvim_get_current_buf()
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  local line = vim.api.nvim_win_get_cursor(0)[1]
  require('custom.implementations').request_all('textDocument/documentSymbol', { textDocument = params.textDocument }, function(symbols)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local ref = M.reference(lines, symbols, params.position) or ('%s:%d'):format(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':.'), line)
    vim.fn.setreg('+', ref)
    vim.api.nvim_echo({ { 'Copied ' .. ref } }, false, {})
  end)
end

return M
