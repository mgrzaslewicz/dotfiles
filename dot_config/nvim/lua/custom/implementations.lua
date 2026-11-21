-- References of the symbol under the cursor together with the references of its implementations (`grR`).
-- An LSP's references of an interface member do not include the overriding methods, so the implementations are
-- asked for (textDocument/implementation) and their references are merged in. Language-agnostic: any server that
-- answers implementation requests works (jdtls, kotlin_lsp). Tests: tests/test_implementations.lua;
-- replayed on jdtls and kotlin-lsp in tests/test_replay_gradle_java.lua and tests/test_replay_gradle_kotlin.lua.
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
-- `<M-m>c` (method_incoming_calls) lists the callers of the method around the cursor, from anywhere in its body (the
-- innermost method symbol of the documentSymbol tree), and of its whole family: the methods it overrides, walked up
-- through the class headers like `grd`, and the implementations of each (textDocument/implementation), so a call
-- through the interface, through the class or through another implementation is listed, as IntelliJ's Ctrl+Alt+H
-- with the hierarchy does. They are listed closest to the method first, so at the bottom of the picker by the prompt:
-- its own calls, then by steps away in the hierarchy (up to a super, down to an override), an ancestor first on a tie.
-- jdtls answers a call through the interface as a call of each implementation too: such a call is the method's own.
-- Supertypes outside the project (`jdt://`, `jar:`) are not read, so the walk stops there.
--
-- `<M-m>r` (method_usages) lists the references of the same family, in the same order, without the declarations.
--
-- `<M-m>i` (method_implementations) is `gri` on the name of the method around the cursor, from anywhere in its body.
--
-- `<M-m>H` (method_supers) and `<M-m>h` (method_overrides) are the method's hierarchy: up, the methods it overrides,
-- walked up through the class headers (type hierarchy is not used: kotlin_lsp answers it with nothing), nearest first;
-- down, its implementations. `<M-m>s` is `grs`, which already works from anywhere in a method body.
--
-- `<M-m>v` (select_method) selects the method around the cursor linewise, with the annotations and comment lines
-- right above it (whether the server's range has them or not).
--
-- `<M-m>C` (method_outgoing_calls) lists the methods the one around the cursor calls, at their declarations, in the
-- order it first calls them.
--
-- `grs` (goto_super, IntelliJ Ctrl+U) goes to the method the one around the cursor overrides, from its name or its
-- body; outside methods to the supertypes of the class, a picker when it names several.
--
-- `grf` (goto_enclosing_method) goes to the name of the method around the cursor, from anywhere in its body, the
-- innermost one when methods nest. It uses the documentSymbol tree of the attached server; in a buffer with none it
-- uses the enclosing function node of the tree-sitter parse, which needs the buffer's parser installed.
--
-- Known limit: the overrides are found only where the server reports them as implementations; a call through a
-- variable of the interface type is a reference of the interface member, as before.
--
-- Known limit: methods are matched by name without their signature (jdtls names them `greet(String)`, kotlin_lsp
-- `greet`), so of overloads in a supertype the first one declared wins; parameter types are not compared.

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

--- The results of `buf_request_all` responses, flattened into one list: a list result is spliced in, a single one added.
---@param responses table<integer, table> `{ err?, result? }` per client id
---@return table[]
function M.results(responses)
  local results = {}
  for _, response in pairs(responses) do
    if response.result then vim.list_extend(results, vim.islist(response.result) and response.result or { response.result }) end
  end
  return results
end

--- Sends `method` to every client of `bufnr` (the current buffer by default) and calls back once with all their
--- results, flattened. Returns a function cancelling the requests.
---
--- The LSP request seam of the config's own features: replayed tests (tests/replay.lua) replace it to answer from
--- recorded contracts, so every feature asks the servers through `M.request_all`, never a local copy of it.
---@param method string
---@param params table
---@param callback fun(results: table[])
---@param bufnr? integer
---@return fun()
function M.request_all(method, params, callback, bufnr)
  return vim.lsp.buf_request_all(bufnr or 0, method, params, function(responses) callback(M.results(responses)) end)
end
-- Looked up on every call, so a replaced `M.request_all` reaches the calls inside this module too.
local function request_all(...) return M.request_all(...) end

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

M.enclosing_class = enclosing_class

--- The identifier of a documentSymbol name: jdtls names a method with its signature (`run(String)`), kotlin_lsp bare.
---@param name string
---@return string
local function identifier(name) return name:match '^[^(%s]+' or name end

--- The method called `name` in a documentSymbol tree, its signature ignored: the first of several overloads.
local function find_method(symbols, name)
  for _, sym in ipairs(symbols) do
    if METHOD_KINDS[sym.kind] and identifier(sym.name) == name then return sym end
    local found = find_method(sym.children or {}, name)
    if found then return found end
  end
end

--- The supertype names in a class header, with their positions: the names after `:` (Kotlin) or `extends` and
--- `implements` (Java), at parenthesis depth 0, up to the `{` that opens the body. `lines` start at the class
--- declaration; `line` is 0-based from there. Constructor arguments, type arguments and type parameter bounds are skipped.
---@param lines string[]
---@return {name: string, line: integer, character: integer}[]
function M.supertypes_in_header(lines)
  local found, depth, angle, listing = {}, 0, 0, false
  local keywords = { extends = true, implements = true, where = true }
  for index, text in ipairs(lines) do
    local col = 1
    while col <= #text do
      local c = text:sub(col, col)
      if c == '{' then return found end
      local top = depth == 0 and angle == 0
      if c == '(' then
        depth = depth + 1
      elseif c == ')' then
        depth = depth - 1
      elseif c == '<' then
        angle = angle + 1
      elseif c == '>' and text:sub(col - 1, col - 1) ~= '-' then
        angle = angle - 1
      elseif top and c == ':' then
        listing = true
      elseif c:match '[%a_]' then
        local word = text:match('^[%w_]+', col)
        if top and (word == 'extends' or word == 'implements') then listing = true end
        if top and listing and not keywords[word] then table.insert(found, { name = word, line = index - 1, character = col - 1 }) end
        col = col + #word - 1
      end
      col = col + 1
    end
  end
  return found
end

--- The lines `first`..`last` (0-based) of the file at `uri`: from its buffer when it is loaded, else from disk.
---@return string[]
local function lines_of(uri, first, last)
  local bufnr = vim.uri_to_bufnr(uri)
  if vim.api.nvim_buf_is_loaded(bufnr) then return vim.api.nvim_buf_get_lines(bufnr, first, last + 1, false) end
  if not vim.startswith(uri, 'file:') then return {} end
  local ok, lines = pcall(vim.fn.readfile, vim.uri_to_fname(uri), '', last + 1)
  return ok and vim.list_slice(lines, first + 1, last + 1) or {}
end

M.lines_of = lines_of

--- Calls back with the declaration (uri and range) of the method called `name` at `target` (a uri and a position in
--- the method) in the supertype it overrides, or nil when it overrides none. Each supertype named in the header of
--- the enclosing class is looked up with go-to-definition, and the first one declaring a method of the same name wins.
---@param target {uri: string, position: table}
---@param name string
---@param callback fun(declared: {uri: string, range: table}?)
local function overridden_at(target, name, callback)
  local document = { uri = target.uri }
  request_all('textDocument/documentSymbol', { textDocument = document }, function(symbols)
    local class = enclosing_class(symbols, target.position)
    if not class or not find_method(class.children or {}, name) then return callback(nil) end
    local first, last = class.range.start.line, class.range['end'].line
    local supertypes = M.supertypes_in_header(lines_of(target.uri, first, last))
    for _, super in ipairs(supertypes) do
      super.line = super.line + first
    end
    local function try(index)
      if index > #supertypes then return callback(nil) end
      local super = supertypes[index]
      local at = { textDocument = document, position = { line = super.line, character = super.character } }
      request_all('textDocument/definition', at, function(definitions)
        local locations = {}
        for _, raw in ipairs(definitions) do
          table.insert(locations, normalize(raw))
        end
        local function search(j)
          if j > #locations then return try(index + 1) end
          request_all('textDocument/documentSymbol', { textDocument = { uri = locations[j].uri } }, function(declared_symbols)
            local method = find_method(declared_symbols, name)
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

--- Calls back with the declaration (uri and range) of the method under the cursor in the supertype it overrides, or nil
--- when it overrides none. The cursor must be on a method its enclosing class declares (see `overridden_at`).
---@param callback fun(declared: {uri: string, range: table}?)
---@param name string? the method's name, by default the word under the cursor
function M.overridden(callback, name)
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  overridden_at({ uri = params.textDocument.uri, position = params.position }, name or vim.fn.expand '<cword>', callback)
end

--- Goes to the implementations of the method `name` at `target` (a uri and a position on its name), in a picker even
--- when there is only one. On an override those of the method it overrides; with none, to the overridden method,
--- else `otherwise()`.
---@param target {uri: string, position: table}
---@param name string
---@param otherwise fun()
local function goto_implementation_at(target, name, otherwise)
  overridden_at(target, name, function(declared)
    local at = declared and { textDocument = { uri = declared.uri }, position = declared.range.start }
      or { textDocument = { uri = target.uri }, position = target.position }
    request_all('textDocument/implementation', at, function(implementations)
      if #implementations > 0 then
        local locations = {}
        for _, raw in ipairs(implementations) do
          table.insert(locations, normalize(raw))
        end
        return M.pick(locations, ('Implementations of %s'):format(name))
      end
      if declared then
        vim.lsp.util.show_document(declared, 'utf-16', { focus = true })
        return
      end
      otherwise()
    end)
  end)
end
M.goto_implementation_at = goto_implementation_at

--- Jumps to the implementations of the word under the cursor (`gri`), in a picker even when there is only one. On an
--- override those of the method it overrides, so `gri` on `Impl.run` lists the implementations of `Iface.run`. With
--- none, goes to the overridden method, else to the definition, so `gri` always lands somewhere.
function M.goto_implementation()
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  goto_implementation_at(
    { uri = params.textDocument.uri, position = params.position },
    vim.fn.expand '<cword>',
    function() require('telescope.builtin').lsp_definitions() end
  )
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

--- The incoming calls (CallHierarchyIncomingCall: `from`, `fromRanges`) of the method at `target` (a
--- TextDocumentPositionParams), once every server has answered.
---@param target table
---@param callback fun(calls: table[])
function M.incoming(target, callback)
  request_all('textDocument/prepareCallHierarchy', target, function(items)
    if #items == 0 then return callback {} end
    local pending, calls = #items, {}
    for _, item in ipairs(items) do
      request_all('callHierarchy/incomingCalls', { item = item }, function(found)
        vim.list_extend(calls, found)
        pending = pending - 1
        if pending == 0 then callback(calls) end
      end)
    end
  end)
end

--- The call sites of the method at `target` (a TextDocumentPositionParams), as locations, once every server has answered.
---@param target table
---@param callback fun(locations: {uri: string, range: table}[])
local function call_sites(target, callback)
  M.incoming(target, function(calls)
    local sites = {}
    for _, call in ipairs(calls) do
      for _, range in ipairs(call.fromRanges) do
        table.insert(sites, { uri = call.from.uri, range = range })
      end
    end
    callback(sites)
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

--- The innermost symbol around `pos` in a documentSymbol tree that `accept` takes (every symbol by default).
---@param accept? fun(sym: table): boolean
local function innermost(symbols, pos, accept)
  accept = accept or function() return true end
  for _, sym in ipairs(symbols) do
    if contains(sym.range, pos) then return innermost(sym.children or {}, pos, accept) or (accept(sym) and sym) or nil end
  end
end

--- Tree-sitter node types of a function or method declaration, across the grammars the config uses.
local FUNCTION_NODES = { function_declaration = true, function_definition = true, method_declaration = true, constructor_declaration = true }

--- Goes to the name of the method around the cursor (`grf`), from anywhere in its body. The LSP's documentSymbol tree
--- answers when a server is attached to the buffer; without one, the enclosing function node of the tree-sitter parse.
function M.goto_enclosing_method()
  if #vim.lsp.get_clients { bufnr = 0, method = 'textDocument/documentSymbol' } == 0 then
    local ok, node = pcall(vim.treesitter.get_node)
    while ok and node and not FUNCTION_NODES[node:type()] do
      node = node:parent()
    end
    if not ok or not node then return vim.notify('Not in a method', vim.log.levels.WARN) end
    local row, col = (node:field('name')[1] or node):start()
    vim.cmd "normal! m'"
    return vim.api.nvim_win_set_cursor(0, { row + 1, col })
  end
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  request_all('textDocument/documentSymbol', { textDocument = params.textDocument }, function(symbols)
    local method = innermost(symbols, params.position, function(sym) return METHOD_KINDS[sym.kind] ~= nil end)
    if not method then return vim.notify('Not in a method', vim.log.levels.WARN) end
    vim.lsp.util.show_document({ uri = params.textDocument.uri, range = method.selectionRange }, 'utf-16', { focus = true })
  end)
end

--- The supers of the method `name` declared at `decl`, transitively: the method it overrides, the one that overrides,
--- and so on up. Calls back with them, nearest first; a cycle or a depth of 20 ends the walk.
---@param decl {uri: string, range: table}
---@param name string
---@param callback fun(supers: {uri: string, range: table}[])
local function supers_of(decl, name, callback)
  local supers, seen = {}, { [decl.uri .. ':' .. decl.range.start.line] = true }
  local function up(from)
    overridden_at({ uri = from.uri, position = from.range.start }, name, function(declared)
      local key = declared and declared.uri .. ':' .. declared.range.start.line
      if not declared or seen[key] or #supers >= 20 then return callback(supers) end
      seen[key] = true
      table.insert(supers, declared)
      up(declared)
    end)
  end
  up(decl)
end

--- The declarations of a method family ranked by their distance in the hierarchy from the method at distance 0, the
--- closest first: `decls[k + 1]` is k steps up (the method, then its supers, nearest first), and the implementations
--- of `decls[k + 1]`, `impls[k + 1]`, are one step below it. Each declaration is ranked once, at its smallest distance;
--- on a tie an ancestor comes before an implementation, else the order found is kept.
---@param decls {uri: string, range: table}[]
---@param impls table[][] Location or LocationLink lists, one per declaration
---@return {uri: string, range: table}[]
function M.by_hierarchy(decls, impls)
  local ranked, index = {}, {}
  local function add(raw, distance)
    local loc = normalize(raw)
    local key = ('%s:%d:%d'):format(loc.uri, loc.range.start.line, loc.range.start.character)
    local found = index[key]
    if found then
      found.distance = math.min(found.distance, distance)
      return
    end
    index[key] = { loc = loc, distance = distance, order = #ranked }
    table.insert(ranked, index[key])
  end
  for k, decl in ipairs(decls) do
    add(decl, k - 1)
  end
  for k, list in ipairs(impls) do
    for _, raw in ipairs(list) do
      add(raw, k)
    end
  end
  table.sort(ranked, function(x, y)
    if x.distance ~= y.distance then return x.distance < y.distance end
    return x.order < y.order
  end)
  return vim.tbl_map(function(entry) return entry.loc end, ranked)
end

--- Calls back with the method around the cursor, from its name or anywhere in its body: its declaration (the uri and
--- the range of its name) and its name without a signature. The innermost method symbol of the documentSymbol tree;
--- outside any method says so and does not call back.
---@param callback fun(decl: {uri: string, range: table}, name: string, symbol: table)
function M.method_around_cursor(callback)
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  request_all('textDocument/documentSymbol', { textDocument = params.textDocument }, function(symbols)
    local method = innermost(symbols, params.position, function(sym) return METHOD_KINDS[sym.kind] ~= nil end)
    if not method then return vim.notify('Not in a method', vim.log.levels.WARN) end
    callback({ uri = params.textDocument.uri, range = method.selectionRange }, identifier(method.name), method)
  end)
end

--- The methods the one around the cursor calls (`<M-m>C`), at their declarations, in the order the method first calls
--- them. Telescope's outgoing calls picker pairs each callee's file with the call's position in the caller, so its
--- entries point at the wrong lines; this one opens the callee.
function M.method_outgoing_calls()
  M.method_around_cursor(function(here, name)
    request_all('textDocument/prepareCallHierarchy', { textDocument = { uri = here.uri }, position = here.range.start }, function(items)
      local pending, calls = #items, {}
      if pending == 0 then return vim.notify(('No outgoing calls of %s'):format(name), vim.log.levels.INFO) end
      for _, item in ipairs(items) do
        request_all('callHierarchy/outgoingCalls', { item = item }, function(found)
          vim.list_extend(calls, found)
          pending = pending - 1
          if pending > 0 then return end
          local function first(call)
            local min
            for _, range in ipairs(call.fromRanges) do
              local s = range.start
              if not min or s.line < min.line or (s.line == min.line and s.character < min.character) then min = s end
            end
            return min or { line = math.huge, character = 0 }
          end
          table.sort(calls, function(a, b)
            local x, y = first(a), first(b)
            return x.line < y.line or (x.line == y.line and x.character < y.character)
          end)
          local callees, seen = {}, {}
          for _, call in ipairs(calls) do
            local key = ('%s:%d:%d'):format(call.to.uri, call.to.selectionRange.start.line, call.to.selectionRange.start.character)
            if not seen[key] then
              seen[key] = true
              table.insert(callees, { uri = call.to.uri, range = call.to.selectionRange })
            end
          end
          if #callees == 0 then return vim.notify(('No outgoing calls of %s'):format(name), vim.log.levels.INFO) end
          M.pick(callees, ('Outgoing calls of %s'):format(name), { keep_order = true })
        end)
      end
    end)
  end)
end

--- The implementations of the method around the cursor (`<M-m>i`, IntelliJ Ctrl+Alt+B on a method): `gri` on its
--- name, from anywhere in its body. Where `gri` would go to the definition, that is the method itself: its name.
function M.method_implementations()
  M.method_around_cursor(function(here, name)
    goto_implementation_at({ uri = here.uri, position = here.range.start }, name, function()
      vim.cmd "normal! m'"
      vim.lsp.util.show_document(here, 'utf-16', { focus = true })
    end)
  end)
end

--- Calls back with the family of the method `name` declared at `here`: the method, the methods it overrides
--- (transitively) and the implementations of each, ranked by `by_hierarchy`, the method first.
---@param here {uri: string, range: table}
---@param name string
---@param callback fun(family: {uri: string, range: table}[])
function M.family_of(here, name, callback)
  supers_of(here, name, function(supers)
    local decls = vim.list_extend({ here }, supers)
    local impls, pending = {}, #decls
    for k, decl in ipairs(decls) do
      request_all('textDocument/implementation', { textDocument = { uri = decl.uri }, position = decl.range.start }, function(found)
        impls[k] = found
        pending = pending - 1
        if pending == 0 then callback(M.by_hierarchy(decls, impls)) end
      end)
    end
  end)
end

--- Asks `ask(member, done)` for the locations of every member of the family of the method around the cursor, then
--- opens them in one picker in family order (each member's in file order, every location once), titled `what` of
--- the method.
---@param what string
---@param ask fun(member: {uri: string, range: table}, done: fun(locations: table[]))
local function pick_for_family(what, ask)
  M.method_around_cursor(function(here, name)
    M.family_of(here, name, function(family)
      local found, left = {}, #family
      for i, member in ipairs(family) do
        ask(member, function(locations)
          found[i] = locations
          left = left - 1
          if left > 0 then return end
          local ordered, seen = {}, {}
          for j = 1, #family do
            for _, loc in ipairs(M.merge { found[j] }) do
              local key = ('%s:%d:%d'):format(loc.uri, loc.range.start.line, loc.range.start.character)
              if not seen[key] then
                seen[key] = true
                table.insert(ordered, loc)
              end
            end
          end
          local title = #family > 1 and '%s of %s, with its supers and implementations' or '%s of %s'
          M.pick(ordered, title:format(what, name), { keep_order = true })
        end)
      end
    end)
  end)
end

--- The first line of a method with what belongs to it above its declaration: the annotations and the comment lines
--- (`//`, `/** … */`) right above it, up to a blank line or code. 0-based, `lines` from the top of the buffer.
---@param lines string[]
---@param first integer the 0-based line the method's range starts on
---@return integer
function M.method_start(lines, first)
  local start = first
  while start > 0 do
    local above = vim.trim(lines[start])
    if not (above:match '^@' or above:match '^/[/*]' or above:match '^%*') then break end
    start = start - 1
  end
  return start
end

--- Selects `symbol` (a documentSymbol of the current buffer) linewise, its annotations and doc comment included.
---@param symbol table
function M.select_symbol(symbol)
  local lines = vim.api.nvim_buf_get_lines(0, 0, symbol.range.start.line, false)
  local first = M.method_start(lines, symbol.range.start.line)
  vim.api.nvim_win_set_cursor(0, { first + 1, 0 })
  vim.cmd 'normal! V'
  vim.api.nvim_win_set_cursor(0, { symbol.range['end'].line + 1, 0 })
end

--- Selects the method around the cursor (`<M-m>v`) linewise, its annotations and doc comment included.
function M.select_method()
  M.method_around_cursor(function(_, _, method) M.select_symbol(method) end)
end

--- The methods the one around the cursor overrides (`<M-m>H`, the method's hierarchy up), walked up through the class
--- headers, the nearest first, so at the bottom of the picker by the prompt.
function M.method_supers()
  M.method_around_cursor(function(here, name)
    supers_of(here, name, function(supers)
      if #supers == 0 then return vim.notify(('%s overrides no method'):format(name), vim.log.levels.INFO) end
      M.pick(supers, ('Supers of %s'):format(name), { keep_order = true })
    end)
  end)
end

--- The methods overriding the one around the cursor (`<M-m>h`, the method's hierarchy down): its implementations,
--- not those of a method it overrides (which `<M-m>i` lists, as `gri`). Always a picker.
function M.method_overrides()
  M.method_around_cursor(function(here, name)
    request_all('textDocument/implementation', { textDocument = { uri = here.uri }, position = here.range.start }, function(found)
      local overrides = M.merge { found }
      if #overrides == 0 then return vim.notify(('No method overrides %s'):format(name), vim.log.levels.INFO) end
      M.pick(overrides, ('Overrides of %s'):format(name))
    end)
  end)
end

--- Incoming calls of the method around the cursor (`<M-m>c`), from its name or anywhere in its body: the calls of
--- its whole family (`M.family_of`) in one picker, closest to the method first, so at the bottom of the picker, by the
--- prompt. The cursor stays where it is.
function M.method_incoming_calls()
  pick_for_family('Incoming calls', function(member, done) call_sites({ textDocument = { uri = member.uri }, position = member.range.start }, done) end)
end

--- Usages of the method around the cursor (`<M-m>r`, IntelliJ Alt+F7): the references of its whole family, its
--- declarations left out, in the order of `<M-m>c`. A method reference (`Foo::run`) is a usage, not a call.
function M.method_usages()
  pick_for_family(
    'Usages',
    function(member, done)
      request_all(
        'textDocument/references',
        { textDocument = { uri = member.uri }, position = member.range.start, context = { includeDeclaration = false } },
        done
      )
    end
  )
end

--- Goes to the supertypes named in the header of `class` (a documentSymbol of the current buffer): one is jumped to,
--- several open in a picker.
local function goto_supertypes(class, params)
  local first = class.range.start.line
  local supertypes = M.supertypes_in_header(vim.api.nvim_buf_get_lines(0, first, class.range['end'].line + 1, false))
  local pending, lists = #supertypes, {}
  if pending == 0 then return vim.notify(('%s names no supertype'):format(class.name)) end
  for index, super in ipairs(supertypes) do
    local at = { textDocument = params.textDocument, position = { line = super.line + first, character = super.character } }
    request_all('textDocument/definition', at, function(definitions)
      lists[index] = definitions
      pending = pending - 1
      if pending > 0 then return end
      local locations = {}
      for _, list in ipairs(lists) do
        for _, raw in ipairs(list) do
          table.insert(locations, normalize(raw))
        end
      end
      if #locations == 0 then return vim.notify(('No supertype of %s found'):format(class.name)) end
      if #locations == 1 then
        vim.lsp.util.show_document(locations[1], 'utf-16', { focus = true })
        return
      end
      M.pick(locations, ('Supertypes of %s'):format(class.name))
    end)
  end
end
M.goto_supertypes = goto_supertypes

--- Goes to super (`grs`, IntelliJ Ctrl+U). In a method, from its name or its body, the method it overrides; elsewhere
--- in a class, its supertypes.
function M.goto_super()
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  request_all('textDocument/documentSymbol', { textDocument = params.textDocument }, function(symbols)
    local sym = innermost(symbols, params.position)
    if sym and METHOD_KINDS[sym.kind] then
      -- The name as written: jdtls names a method with its signature, `run(String)`.
      local name = vim.api.nvim_buf_get_text(0, sym.selectionRange.start.line, 0, sym.selectionRange.start.line, -1, {})[1]
      name = name:sub(vim.str_byteindex(name, 'utf-16', sym.selectionRange.start.character) + 1):match '^[%w_]+' or sym.name
      return M.overridden(function(declared)
        if not declared then return vim.notify(('%s overrides no method'):format(name)) end
        vim.lsp.util.show_document(declared, 'utf-16', { focus = true })
      end, name)
    end
    local class = enclosing_class(symbols, params.position)
    if not class then return vim.notify 'Not in a class' end
    goto_supertypes(class, params)
  end)
end

--- Quickfix items of `locations`, each keeping the `name` and `group` of its location. Neovim sorts such items by file
--- and line; `keep_order` keeps the given order instead.
---@param locations {uri: string, range: table, name?: string, group?: string}[]
---@param keep_order? boolean
function M.items(locations, keep_order)
  local items = {}
  for _, location in ipairs(locations) do
    local item = vim.lsp.util.locations_to_items({ location }, 'utf-16')[1] ---@cast item table
    item.name, item.group = location.name, location.group
    table.insert(items, item)
  end
  if not keep_order then
    table.sort(items, function(a, b)
      if a.filename ~= b.filename then return a.filename < b.filename end
      if a.lnum ~= b.lnum then return a.lnum < b.lnum end
      return a.col < b.col
    end)
  end
  return items
end

--- Entry maker for `pick` with columns: the name, the group, then the file and line.
---@param width integer width of the name column
function M.column_entry_maker(width)
  local base = require('telescope.make_entry').gen_from_quickfix {}
  local row = ('%%-%ds  %%-8s  %%s:%%d'):format(width)
  return function(item)
    local entry = base(item)
    entry.ordinal = ('%s %s %s'):format(item.name or '', item.group or '', entry.ordinal)
    entry.display = function(_) return row:format(item.name or '', item.group or '', vim.fn.fnamemodify(item.filename, ':t'), item.lnum) end
    return entry
  end
end

--- Shows `locations` in a Telescope picker titled `title`. Options: `keep_order` shows them in the given order, and
--- `columns` shows each with its name and group in columns (see `column_entry_maker`).
---@param locations {uri: string, range: table, name?: string, group?: string}[]
---@param title string
---@param opts? {keep_order?: boolean, columns?: boolean}
function M.pick(locations, title, opts)
  opts = opts or {}
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local entry_maker = require('telescope.make_entry').gen_from_quickfix {}
  if opts.columns then
    local width = 1
    for _, location in ipairs(locations) do
      width = math.max(width, #(location.name or ''))
    end
    entry_maker = M.column_entry_maker(width)
  end
  pickers
    .new({}, {
      prompt_title = title,
      finder = finders.new_table {
        results = M.items(locations, opts.keep_order),
        entry_maker = entry_maker,
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
