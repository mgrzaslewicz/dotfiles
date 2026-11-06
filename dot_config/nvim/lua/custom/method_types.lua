-- Types related to the method under the cursor (`grm`), in one picker: the return type first, then the parameter types,
-- then the types the body uses. Works on the method's definition and in its body. Composed types count with their
-- parts (`List<Item>` gives List and Item); duplicates are dropped. Tests: tests/test_method_types.lua.
--
-- The method is the innermost method symbol around the cursor. Its text is scanned for identifiers (see `identifiers`),
-- each name once. Every identifier is resolved twice: go-to-definition, kept when it lands on a class-like symbol, and
-- go-to-type-definition, which gives a variable's type or a called method's return type. The picker is Telescope, so
-- an entry opens in a split with <C-v> like the other LSP pickers.
--
-- Known limit: a type without symbols on the server side (a library class with no source) is dropped.

local implementations = require 'custom.implementations'

local M = {}

-- Keywords of the languages that never name a type. Anything else the server cannot resolve is filtered by it.
local KEYWORDS = {
  fun = true,
  val = true,
  var = true,
  ['return'] = true,
  new = true,
  public = true,
  private = true,
  protected = true,
  internal = true,
  static = true,
  final = true,
  abstract = true,
  override = true,
  open = true,
  suspend = true,
  inline = true,
  void = true,
}

--- The identifiers of a method, in priority order: the return type, the parameter types, then the body. Each name is
--- listed once, at its first occurrence. The header runs to the `{`, `=` or `;` that ends it, at parenthesis depth 0.
--- Identifiers after `@` (annotations) are skipped, and so are the names of Kotlin parameters (followed by `:`).
---@param lines string[] the method's text, from its first line; `lines[1]` starts at `origin`
---@param origin {line: integer, character: integer} buffer position of `lines[1]`'s first character
---@param name {line: integer, character: integer} buffer position of the method name, which is not a type
---@return {name: string, line: integer, character: integer, group: 'returns'|'params'|'body'}[]
function M.identifiers(lines, origin, name)
  local buckets = { returns = {}, params = {}, body = {} }
  local depth, in_body, in_comment = 0, false, false
  for index, text in ipairs(lines) do
    local line = origin.line + index - 1
    local base = index == 1 and origin.character or 0
    local col = 1
    while col <= #text do
      local c = text:sub(col, col)
      local word = text:match('^[%a_][%w_]*', col)
      if in_comment then
        local close = text:find('*/', col, true)
        if close then
          in_comment = false
          col = close + 2
        else
          break
        end
      elseif text:sub(col, col + 1) == '/*' then
        in_comment = true
        col = col + 2
      elseif text:sub(col, col + 1) == '//' then
        break
      elseif c == '"' then
        col = (text:find('"', col + 1, true) or #text) + 1
      elseif not in_body and depth == 0 and (c == '{' or c == '=' or c == ';') then
        in_body = true
        col = col + 1
      elseif c == '(' then
        depth = depth + 1
        col = col + 1
      elseif c == ')' then
        depth = depth - 1
        col = col + 1
      elseif word then
        local start = col
        col = col + #word
        local character = base + start - 1
        local is_name = line == name.line and character == name.character
        local prev = text:sub(1, start - 1):match '(%S)%s*$'
        local after = text:sub(col):match '^%s*(.)'
        local parameter_name = not in_body and depth > 0 and after == ':'
        if not is_name and prev ~= '@' and not KEYWORDS[word] and not parameter_name then
          local bucket = in_body and 'body' or (depth > 0 and 'params' or 'returns')
          table.insert(buckets[bucket], { name = word, line = line, character = character })
        end
      elseif c:match '%d' then
        col = col + #text:match('^[%w_]*', col)
      else
        col = col + 1
      end
    end
  end

  local out, seen = {}, {}
  for _, bucket in ipairs { 'returns', 'params', 'body' } do
    for _, id in ipairs(buckets[bucket]) do
      if not seen[id.name] then
        seen[id.name] = true
        id.group = bucket
        table.insert(out, id)
      end
    end
  end
  return out
end

--- Entries with the duplicates dropped: a type is listed once per file and declaration line. Order is kept.
---@param entries {uri: string, range: table}[]
---@return {uri: string, range: table}[]
function M.unique(entries)
  local seen, out = {}, {}
  for _, entry in ipairs(entries) do
    local key = ('%s:%d'):format(entry.uri, entry.range.start.line)
    if not seen[key] then
      seen[key] = true
      table.insert(out, entry)
    end
  end
  return out
end

--- The innermost method around `pos` in a documentSymbol tree.
local function enclosing_method(symbols, pos)
  for _, sym in ipairs(symbols) do
    if implementations.contains(sym.range, pos) then
      return enclosing_method(sym.children or {}, pos) or (implementations.METHOD_KINDS[sym.kind] and sym) or nil
    end
  end
end

--- The class-like symbol whose name starts at `pos` in a documentSymbol tree.
local function class_named_at(symbols, pos)
  for _, sym in ipairs(symbols) do
    local start = sym.selectionRange.start
    if implementations.CLASS_KINDS[sym.kind] and start.line == pos.line and start.character == pos.character then return sym end
    local found = class_named_at(sym.children or {}, pos)
    if found then return found end
  end
end

--- Calls back with the declarations of the class-like symbols among `locations`, in their order.
---@param locations {uri: string, range: table}[]
---@param callback fun(classes: {uri: string, range: table}[])
local function classes_among(locations, callback)
  local pending, found = #locations, {}
  if pending == 0 then return callback {} end
  for index, loc in ipairs(locations) do
    implementations.request_all('textDocument/documentSymbol', { textDocument = { uri = loc.uri } }, function(symbols)
      local sym = class_named_at(symbols, loc.range.start)
      if sym then found[index] = { uri = loc.uri, range = sym.selectionRange } end
      pending = pending - 1
      if pending == 0 then
        local out = {}
        for i = 1, #locations do
          if found[i] then table.insert(out, found[i]) end
        end
        callback(out)
      end
    end)
  end
end

--- The name of the symbol declared at `pos` in a documentSymbol tree.
local function name_at(symbols, pos)
  for _, sym in ipairs(symbols) do
    local start = sym.selectionRange.start
    if start.line == pos.line and start.character == pos.character then return sym.name end
    local found = name_at(sym.children or {}, pos)
    if found then return found end
  end
end

--- Sets the `name` of each type to the name it is declared with; `fallback` when the server knows none. Calls back with
--- `types`, once all are named.
---@param types {uri: string, range: table}[]
---@param fallback string
---@param callback fun(types: {uri: string, range: table, name: string}[])
local function name_all(types, fallback, callback)
  if #types == 0 then return callback(types) end
  local pending = #types
  for _, found in ipairs(types) do
    implementations.request_all('textDocument/documentSymbol', { textDocument = { uri = found.uri } }, function(symbols)
      ---@cast found table
      found.name = name_at(symbols, found.range.start) or fallback
      pending = pending - 1
      if pending == 0 then callback(types) end
    end)
  end
end

--- Calls back with the types an identifier stands for: the class it names, then the type of what it refers to. Each is
--- named by its declaration, or by the identifier when the server does not know the declaration.
---@param uri string
---@param id {name: string, line: integer, character: integer}
---@param callback fun(types: {uri: string, range: table, name: string}[])
local function types_of(uri, id, callback)
  local at = { textDocument = { uri = uri }, position = { line = id.line, character = id.character } }
  implementations.request_all('textDocument/definition', at, function(definitions)
    classes_among(vim.tbl_map(implementations.normalize, definitions), function(named)
      implementations.request_all(
        'textDocument/typeDefinition',
        at,
        function(type_definitions) name_all(vim.list_extend(named, vim.tbl_map(implementations.normalize, type_definitions)), id.name, callback) end
      )
    end)
  end)
end

--- Calls back with the types related to the method under the cursor, in order: return types, parameter types, then the
--- types the body uses; duplicates dropped. Each type carries its `name` and the `group` it comes from. Calls back with
--- nil when the cursor is in no method.
---@param callback fun(types: {uri: string, range: table, name: string, group: string}[]?)
function M.collect(callback)
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  implementations.request_all('textDocument/documentSymbol', { textDocument = params.textDocument }, function(symbols)
    local method = enclosing_method(symbols, params.position)
    if not method then return callback(nil) end
    local first = method.range.start
    local lines = vim.api.nvim_buf_get_lines(0, first.line, method.range['end'].line + 1, false)
    lines[1] = lines[1]:sub(first.character + 1)
    local ids = M.identifiers(lines, first, method.selectionRange.start)
    if #ids == 0 then return callback {} end
    local per_id, pending = {}, #ids
    for index, id in ipairs(ids) do
      types_of(params.textDocument.uri, id, function(found)
        for _, entry in ipairs(found) do
          ---@cast entry table
          entry.group = id.group
        end
        per_id[index] = found
        pending = pending - 1
        if pending == 0 then
          local ordered = {}
          for i = 1, #ids do
            vim.list_extend(ordered, per_id[i])
          end
          callback(M.unique(ordered))
        end
      end)
    end
  end)
end

--- Opens the types related to the method under the cursor (`grm`) in a Telescope picker.
function M.picker()
  local word = vim.fn.expand '<cword>'
  M.collect(function(types)
    if not types then return vim.notify('No method around the cursor', vim.log.levels.INFO) end
    if #types == 0 then return vim.notify('No types related to ' .. word, vim.log.levels.INFO) end
    implementations.pick(types, ('Types of %s'):format(word), { keep_order = true, columns = true })
  end)
end

--- Goes to the return type of the method under the cursor (`grM`): straight there when it has one, else a picker of
--- them when it has several.
function M.returns_picker()
  local word = vim.fn.expand '<cword>'
  M.collect(function(types)
    if not types then return vim.notify('No method around the cursor', vim.log.levels.INFO) end
    local returns = vim.tbl_filter(function(entry) return entry.group == 'returns' end, types)
    if #returns == 0 then return vim.notify('No return type of ' .. word, vim.log.levels.INFO) end
    if #returns == 1 then
      vim.lsp.util.show_document(returns[1], 'utf-16', { focus = true })
    else
      implementations.pick(returns, ('Return types of %s'):format(word), { keep_order = true, columns = true })
    end
  end)
end

return M
