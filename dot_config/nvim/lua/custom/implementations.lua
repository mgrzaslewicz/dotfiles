-- References of the symbol under the cursor together with the references of its implementations (`grR`).
-- An LSP's references of an interface member do not include the overriding methods, so the implementations are
-- asked for (textDocument/implementation) and their references are merged in. Language-agnostic: any server that
-- answers implementation requests works (jdtls, kotlin_lsp). Tests: tests/test_implementations.lua.
--
-- `gri` (goto_implementation) on an override lists the implementations of the method it overrides, and `grd`
-- (goto_definition) goes to that method. The overridden method is found through the class header: the supertypes it
-- names, resolved by go-to-definition, that declare a method of the same name (type hierarchy is not used: kotlin_lsp
-- answers it with nothing). `gri` falls back to the overridden method, then to the definition, when there are no
-- implementations.
--
-- `grc` (incoming_calls) on an override adds the callers of the method it overrides: a call through the interface
-- type is a call of the interface member, which the server's incoming calls of the override leave out (IntelliJ's
-- Ctrl+Alt+H lists both). Elsewhere it is Telescope's incoming calls picker.
--
-- Known limit: the overrides are found only where the server reports them as implementations; a call through a
-- variable of the interface type is a reference of the interface member, as before.

local M = {}

--- A Location or a LocationLink as a Location.
---@param loc table
---@return {uri: string, range: table}
local function normalize(loc) return { uri = loc.uri or loc.targetUri, range = loc.range or loc.targetSelectionRange } end
M.normalize = normalize

--- Merges location lists into one: duplicates (same file and start) dropped, sorted by file, then position.
---@param lists table[] lists of Location or LocationLink
---@return {uri: string, range: table}[]
function M.merge(lists)
  local seen, merged = {}, {}
  for _, list in ipairs(lists) do
    for _, raw in ipairs(list) do
      local loc = normalize(raw)
      local start = loc.range.start
      local key = ('%s:%d:%d'):format(loc.uri, start.line, start.character)
      if not seen[key] then
        seen[key] = true
        table.insert(merged, loc)
      end
    end
  end
  table.sort(merged, function(a, b)
    if a.uri ~= b.uri then return a.uri < b.uri end
    if a.range.start.line ~= b.range.start.line then return a.range.start.line < b.range.start.line end
    return a.range.start.character < b.range.start.character
  end)
  return merged
end

--- Sends `method` to every client of the current buffer and calls back once with all their results, flattened.
---@param method string
---@param params table
---@param callback fun(results: table[])
local function request_all(method, params, callback)
  vim.lsp.buf_request_all(0, method, params, function(responses)
    local results = {}
    for _, response in pairs(responses) do
      if response.result then vim.list_extend(results, vim.islist(response.result) and response.result or { response.result }) end
    end
    callback(results)
  end)
end
M.request_all = request_all

--- Calls `callback` with the references of the symbol under the cursor merged with the references of each of its
--- implementations, once every server has answered.
---@param callback fun(locations: {uri: string, range: table}[])
function M.collect(callback)
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  request_all('textDocument/implementation', params, function(implementations)
    local targets = { { textDocument = params.textDocument, position = params.position } }
    for _, raw in ipairs(implementations) do
      local impl = normalize(raw)
      table.insert(targets, { textDocument = { uri = impl.uri }, position = impl.range.start })
    end
    local pending, lists = #targets, {}
    for index, target in ipairs(targets) do
      target.context = { includeDeclaration = true }
      request_all('textDocument/references', target, function(locations)
        lists[index] = locations
        pending = pending - 1
        if pending == 0 then callback(M.merge(lists)) end
      end)
    end
  end)
end

local CLASS_KINDS = { [5] = true, [10] = true, [11] = true, [23] = true } -- class, enum, interface, struct
local METHOD_KINDS = { [6] = true, [12] = true } -- method, function
M.CLASS_KINDS, M.METHOD_KINDS = CLASS_KINDS, METHOD_KINDS

---@return boolean
local function contains(range, pos)
  local s, e = range.start, range['end']
  if pos.line < s.line or pos.line > e.line then return false end
  if pos.line == s.line and pos.character < s.character then return false end
  return not (pos.line == e.line and pos.character > e.character)
end
M.contains = contains

--- The innermost class-like symbol around `pos` in a documentSymbol tree.
local function enclosing_class(symbols, pos)
  for _, sym in ipairs(symbols) do
    if contains(sym.range, pos) then return enclosing_class(sym.children or {}, pos) or (CLASS_KINDS[sym.kind] and sym) or nil end
  end
end

--- The method called `name` in a documentSymbol tree.
local function find_method(symbols, name)
  for _, sym in ipairs(symbols) do
    if sym.name == name and METHOD_KINDS[sym.kind] then return sym end
    local found = find_method(sym.children or {}, name)
    if found then return found end
  end
end

--- The supertype names in a class header, with their positions: the names after `:` (Kotlin) or `extends` and
--- `implements` (Java), at parenthesis depth 0, up to the `{` that opens the body. `lines` start at the class
--- declaration; `line` is 0-based from there. Constructor arguments and generic arguments are skipped or not named.
---@param lines string[]
---@return {name: string, line: integer, character: integer}[]
function M.supertypes_in_header(lines)
  local found, depth, listing = {}, 0, false
  local keywords = { extends = true, implements = true, where = true }
  for index, text in ipairs(lines) do
    local col = 1
    while col <= #text do
      local c = text:sub(col, col)
      if c == '{' then return found end
      if c == '(' then
        depth = depth + 1
      elseif c == ')' then
        depth = depth - 1
      elseif depth == 0 and c == ':' then
        listing = true
      elseif c:match '[%a_]' then
        local word = text:match('^[%w_]+', col)
        if depth == 0 and (word == 'extends' or word == 'implements') then listing = true end
        if depth == 0 and listing and not keywords[word] then table.insert(found, { name = word, line = index - 1, character = col - 1 }) end
        col = col + #word - 1
      end
      col = col + 1
    end
  end
  return found
end

--- Calls back with the declaration (uri and range) of the method under the cursor in the supertype it overrides, or nil
--- when it overrides none. The cursor must be on a method its enclosing class declares. Each supertype named in the
--- class header is looked up with go-to-definition, and the first one declaring a method of the same name wins.
---@param callback fun(declared: {uri: string, range: table}?)
function M.overridden(callback)
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  local word = vim.fn.expand '<cword>'
  request_all('textDocument/documentSymbol', { textDocument = params.textDocument }, function(symbols)
    local class = enclosing_class(symbols, params.position)
    if not class or not find_method(class.children or {}, word) then return callback(nil) end
    local first, last = class.range.start.line, class.range['end'].line
    local lines = vim.api.nvim_buf_get_lines(0, first, last + 1, false)
    local supertypes = M.supertypes_in_header(lines)
    for _, super in ipairs(supertypes) do
      super.line = super.line + first
    end
    local function try(index)
      if index > #supertypes then return callback(nil) end
      local super = supertypes[index]
      local at = { textDocument = params.textDocument, position = { line = super.line, character = super.character } }
      request_all('textDocument/definition', at, function(definitions)
        local locations = {}
        for _, raw in ipairs(definitions) do
          table.insert(locations, normalize(raw))
        end
        local function search(j)
          if j > #locations then return try(index + 1) end
          request_all('textDocument/documentSymbol', { textDocument = { uri = locations[j].uri } }, function(declared_symbols)
            local method = find_method(declared_symbols, word)
            if method then return callback { uri = locations[j].uri, range = method.selectionRange } end
            search(j + 1)
          end)
        end
        search(1)
      end)
    end
    try(1)
  end)
end

--- Jumps to the implementations of the word under the cursor (`gri`), in a picker even when there is only one. On an
--- override those of the method it overrides, so `gri` on `Impl.run` lists the implementations of `Iface.run`. With
--- none, goes to the overridden method, else to the definition, so `gri` always lands somewhere.
function M.goto_implementation()
  M.overridden(function(declared)
    local word = vim.fn.expand '<cword>'
    local target = declared and { textDocument = { uri = declared.uri }, position = declared.range.start } or vim.lsp.util.make_position_params(0, 'utf-16')
    request_all('textDocument/implementation', target, function(implementations)
      if #implementations > 0 then
        local locations = {}
        for _, raw in ipairs(implementations) do
          table.insert(locations, normalize(raw))
        end
        return M.pick(locations, ('Implementations of %s'):format(word))
      end
      if declared then
        vim.lsp.util.show_document(declared, 'utf-16', { focus = true })
        return
      end
      require('telescope.builtin').lsp_definitions()
    end)
  end)
end

--- Jumps to the definition of the word under the cursor (`grd`). On an override that is the method it overrides, so
--- `grd` leaves the class for the interface member; elsewhere the definition.
function M.goto_definition()
  M.overridden(function(declared)
    if declared then
      vim.lsp.util.show_document(declared, 'utf-16', { focus = true })
      return
    end
    require('telescope.builtin').lsp_definitions()
  end)
end

--- The call sites of the method at `target` (a TextDocumentPositionParams), as locations, once every server has answered.
---@param target table
---@param callback fun(locations: {uri: string, range: table}[])
local function call_sites(target, callback)
  request_all('textDocument/prepareCallHierarchy', target, function(items)
    if #items == 0 then return callback {} end
    local pending, sites = #items, {}
    for _, item in ipairs(items) do
      request_all('callHierarchy/incomingCalls', { item = item }, function(calls)
        for _, call in ipairs(calls) do
          for _, range in ipairs(call.fromRanges) do
            table.insert(sites, { uri = call.from.uri, range = range })
          end
        end
        pending = pending - 1
        if pending == 0 then callback(sites) end
      end)
    end
  end)
end

--- Incoming calls of the method under the cursor (`grc`). On an override, merged with the calls of the method it
--- overrides, in one picker; elsewhere Telescope's incoming calls.
function M.incoming_calls()
  local word = vim.fn.expand '<cword>'
  local here = vim.lsp.util.make_position_params(0, 'utf-16')
  M.overridden(function(declared)
    if not declared then return require('telescope.builtin').lsp_incoming_calls() end
    local super = { textDocument = { uri = declared.uri }, position = declared.range.start }
    call_sites(here, function(own)
      call_sites(super, function(inherited) M.pick(M.merge { own, inherited }, ('Incoming calls of %s, with the overridden method'):format(word)) end)
    end)
  end)
end

--- Shows `locations` in a Telescope picker titled `title`.
---@param locations {uri: string, range: table}[]
---@param title string
function M.pick(locations, title)
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  pickers
    .new({}, {
      prompt_title = title,
      finder = finders.new_table {
        results = vim.lsp.util.locations_to_items(locations, 'utf-16'),
        entry_maker = require('telescope.make_entry').gen_from_quickfix {},
      },
      previewer = conf.qflist_previewer {},
      sorter = conf.generic_sorter {},
    })
    :find()
end

--- Shows the references of the word under the cursor, with those of its implementations, in a Telescope picker.
function M.references()
  local word = vim.fn.expand '<cword>'
  M.collect(function(locations) M.pick(locations, ('References of %s, with implementations'):format(word)) end)
end

return M
