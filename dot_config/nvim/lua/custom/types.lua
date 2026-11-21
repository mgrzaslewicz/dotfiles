-- `<M-t>`: actions on the type around the cursor (the innermost class, interface, enum or struct of the
-- documentSymbol tree), from anywhere in it, as `<M-m>` acts on the method. Tests: tests/test_types.lua; replayed on
-- jdtls in tests/test_replay_gradle_java.lua.
--
-- `<M-t>s` goes to the supertypes the type's header names (`grs` outside a method): one is jumped to, several open a
-- picker. `<M-t>H` lists all its supertypes up the hierarchy, nearest first: the header's, resolved by
-- go-to-definition, then theirs (type hierarchy is not used: kotlin_lsp answers it with nothing). `<M-t>h` lists its
-- subtypes (textDocument/implementation at its name). `<M-t>T` shows both as a tree (custom/type_hierarchy.lua).
--
-- `<M-t>i` is `gri` on the type's name (where `gri` would go to the definition, the type itself: its name); `<M-t>r`
-- lists the type's usages, its declaration left out.
--
-- `<M-t>m` lists the type's own members (IntelliJ Ctrl+F12 on the class): its children in the documentSymbol tree, in
-- file order; a nested type is listed, not its members.
--
-- `<M-t>n` renames the type (<leader>rn on its name, see custom/refactor.lua); `<M-t>v` selects it linewise, with its
-- annotations and doc comment.
--
-- `<M-t>M` adds the members of its supertypes (those of `<M-t>H`, nearest first), each named `Type.member`; a member
-- an override below already lists is left out (matched by name, so of overloads only the lowest declaring type's).
--
-- `<M-t>t` lists the test files using the type: its test counterpart (`FooTest`, custom/jvm/test_pair.lua) first when
-- it exists, then the test files referencing it, each at its first use. `<M-t>u` runs those files through neotest.
--
-- Known limit: a supertype outside the project (`jdt://`, `jar:`) is listed, but its own supertypes are not read.

local implementations = require 'custom.implementations'

local M = {}

local function request_all(...) return implementations.request_all(...) end

--- Calls back with the type around the cursor: its declaration (uri, range of its name), its name and its symbol.
--- Outside any type says so and does not call back.
---@param callback fun(decl: {uri: string, range: table}, name: string, symbol: table)
function M.type_around_cursor(callback)
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  request_all('textDocument/documentSymbol', { textDocument = params.textDocument }, function(symbols)
    local class = implementations.enclosing_class(symbols, params.position)
    if not class then return vim.notify('Not in a type', vim.log.levels.WARN) end
    callback({ uri = params.textDocument.uri, range = class.selectionRange }, class.name, class)
  end)
end

--- The class-like symbol declared at `pos` (its name holds it) in a documentSymbol tree, else the innermost one whose
--- range holds it.
local function class_at(symbols, pos, strict)
  for _, sym in ipairs(symbols) do
    if implementations.CLASS_KINDS[sym.kind] and implementations.contains(sym.selectionRange, pos) then return sym end
    local found = class_at(sym.children or {}, pos, true)
    if found then return found end
  end
  if not strict then return implementations.enclosing_class(symbols, pos) end
end

--- The class-like symbol declared at `pos` (its name holds it) in a documentSymbol tree, or nil.
function M.class_declared_at(symbols, pos) return class_at(symbols, pos, true) end

--- Calls back with the supertypes the header of `class` (a symbol in the file at `uri`) names, as declarations,
--- each with the `name` the header gives it. Asks the servers of `bufnr` (default: the current buffer).
local function direct_supertypes(uri, class, callback, bufnr)
  local first = class.range.start.line
  local names = implementations.supertypes_in_header(implementations.lines_of(uri, first, class.range['end'].line))
  local pending, lists = #names, {}
  if pending == 0 then return callback {} end
  for index, super in ipairs(names) do
    local at = { textDocument = { uri = uri }, position = { line = super.line + first, character = super.character } }
    request_all('textDocument/definition', at, function(definitions)
      lists[index] = vim.tbl_map(function(d) return vim.tbl_extend('force', implementations.normalize(d), { name = super.name }) end, definitions)
      pending = pending - 1
      if pending == 0 then callback(vim.iter(lists):flatten():totable()) end
    end, bufnr)
  end
end

M.direct_supertypes = direct_supertypes

--- Calls back with all the supertypes of `class` (a symbol in the file at `uri`), breadth first (nearest first), each
--- once; at most 50.
local function all_supertypes(uri, class, callback)
  local found, seen = {}, {}
  local queue = { { uri = uri, class = class } }
  local function next_one()
    local current = table.remove(queue, 1)
    if not current or #found >= 50 then return callback(found) end
    direct_supertypes(current.uri, current.class, function(supers)
      local pending = #supers
      if pending == 0 then return next_one() end
      for _, super in ipairs(supers) do
        local key = ('%s:%d'):format(super.uri, super.range.start.line)
        if not seen[key] then
          seen[key] = true
          table.insert(found, super)
        end
      end
      -- Their own supertypes come next, in the order found.
      local classes = {}
      for i, super in ipairs(supers) do
        request_all('textDocument/documentSymbol', { textDocument = { uri = super.uri } }, function(symbols)
          classes[i] = class_at(symbols, super.range.start)
          pending = pending - 1
          if pending > 0 then return end
          for k = 1, #supers do
            if classes[k] then table.insert(queue, { uri = supers[k].uri, class = classes[k] }) end
          end
          next_one()
        end)
      end
    end)
  end
  next_one()
end

--- Goes to the supertypes the header of the type around the cursor names (`<M-t>s`): one is jumped to, several open
--- a picker.
function M.goto_supertypes()
  M.type_around_cursor(function(_, _, class) implementations.goto_supertypes(class, vim.lsp.util.make_position_params(0, 'utf-16')) end)
end

--- All the supertypes of the type around the cursor (`<M-t>H`), up the hierarchy, nearest first.
function M.supertypes()
  M.type_around_cursor(function(here, name, class)
    all_supertypes(here.uri, class, function(supers)
      if #supers == 0 then return vim.notify(('%s has no supertype'):format(name), vim.log.levels.INFO) end
      implementations.pick(supers, ('Supertypes of %s, up the hierarchy'):format(name), { keep_order = true })
    end)
  end)
end

--- The subtypes of the type around the cursor (`<M-t>h`), in a picker even for one.
function M.subtypes()
  M.type_around_cursor(function(here, name)
    request_all('textDocument/implementation', { textDocument = { uri = here.uri }, position = here.range.start }, function(found)
      local subtypes = implementations.merge { found }
      if #subtypes == 0 then return vim.notify(('No subtypes of %s'):format(name), vim.log.levels.INFO) end
      implementations.pick(subtypes, ('Subtypes of %s'):format(name))
    end)
  end)
end

--- The implementations of the type around the cursor (`<M-t>i`): `gri` on its name, from anywhere in it.
function M.implementations()
  M.type_around_cursor(function(here, name)
    implementations.goto_implementation_at({ uri = here.uri, position = here.range.start }, name, function()
      vim.cmd "normal! m'"
      vim.lsp.util.show_document(here, 'utf-16', { focus = true })
    end)
  end)
end

--- The usages of the type around the cursor (`<M-t>r`, IntelliJ Alt+F7 on it), its declaration left out.
function M.usages()
  M.type_around_cursor(function(here, name)
    local params = { textDocument = { uri = here.uri }, position = here.range.start, context = { includeDeclaration = false } }
    request_all('textDocument/references', params, function(found)
      local usages = implementations.merge { found }
      if #usages == 0 then return vim.notify(('No usages of %s'):format(name), vim.log.levels.INFO) end
      implementations.pick(usages, ('Usages of %s'):format(name))
    end)
  end)
end

--- The members of `class` (a symbol in the file at `uri`), in file order, each at its name.
local function members_of(uri, class)
  local members = vim.tbl_map(
    function(child) return { uri = uri, range = child.selectionRange, name = vim.trim(child.name:match '^[^:]+'), kind = child.kind } end,
    class.children or {}
  )
  table.sort(members, function(a, b)
    local x, y = a.range.start, b.range.start
    return x.line < y.line or (x.line == y.line and x.character < y.character)
  end)
  return members
end

--- The members of the type around the cursor (`<M-t>m`), in file order, each at its name.
function M.members()
  M.type_around_cursor(function(here, name, class)
    local members = members_of(here.uri, class)
    if #members == 0 then return vim.notify(('%s has no members'):format(name), vim.log.levels.INFO) end
    implementations.pick(members, ('Members of %s'):format(name), { keep_order = true, columns = true })
  end)
end

--- Selects the type around the cursor (`<M-t>v`) linewise, its annotations and doc comment included.
function M.select_type()
  M.type_around_cursor(function(_, _, class) implementations.select_symbol(class) end)
end

--- Calls back with the test files using the type around the cursor, each as a location (its first use, or the top of
--- the counterpart), and the type's name.
---@param callback fun(files: {uri: string, range: table}[], name: string)
function M.test_files(callback)
  local method_tests = require 'custom.method_tests'
  M.type_around_cursor(function(here, name)
    local params = { textDocument = { uri = here.uri }, position = here.range.start, context = { includeDeclaration = false } }
    request_all('textDocument/references', params, function(found)
      local files, seen = {}, {}
      local counterpart = require('custom.jvm.test_pair').counterpart(vim.uri_to_fname(here.uri))
      if counterpart and vim.uv.fs_stat(counterpart) then
        local uri = vim.uri_from_fname(counterpart)
        seen[uri] = true
        table.insert(files, { uri = uri, range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 } } })
      end
      for _, ref in ipairs(implementations.merge { found }) do
        if not seen[ref.uri] and method_tests.is_test_file(vim.uri_to_fname(ref.uri)) then
          seen[ref.uri] = true
          table.insert(files, ref)
        end
      end
      callback(files, name)
    end)
  end)
end

--- Goes to the test files using the type around the cursor (`<M-t>t`): one is jumped to, several open a picker.
function M.goto_tests()
  M.test_files(function(files, name)
    if #files == 0 then return vim.notify(('No tests use %s'):format(name), vim.log.levels.INFO) end
    if #files == 1 then
      vim.cmd "normal! m'"
      vim.lsp.util.show_document(files[1], 'utf-16', { focus = true })
      return
    end
    implementations.pick(files, ('Tests of %s'):format(name), { keep_order = true })
  end)
end

--- Runs the test files using the type around the cursor (`<M-t>u`) through neotest, file by file.
function M.run_tests()
  M.test_files(function(files, name)
    if #files == 0 then return vim.notify(('No tests use %s'):format(name), vim.log.levels.INFO) end
    local neotest = require 'neotest'
    for _, file in ipairs(files) do
      neotest.run.run(vim.uri_to_fname(file.uri))
    end
  end)
end

--- The members of the type around the cursor and of its supertypes (`<M-t>M`): its own, then each supertype's,
--- nearest first, each named `Type.member`; a member an override below lists already is left out.
function M.members_with_supertypes()
  M.type_around_cursor(function(here, name, class)
    all_supertypes(here.uri, class, function(supers)
      local classes, pending = {}, #supers
      local function done()
        local out, seen = {}, {}
        local function add(owner, members)
          for _, member in ipairs(members) do
            local id = member.name:match '^[^(%s]+' or member.name
            if not seen[id] then
              seen[id] = true
              member.name = owner .. '.' .. id
              table.insert(out, member)
            end
          end
        end
        add(name, members_of(here.uri, class))
        for i, super in ipairs(supers) do
          if classes[i] then add(classes[i].name, members_of(super.uri, classes[i])) end
        end
        if #out == 0 then return vim.notify(('%s has no members'):format(name), vim.log.levels.INFO) end
        implementations.pick(out, ('Members of %s, with its supertypes'):format(name), { keep_order = true, columns = true })
      end
      if pending == 0 then return done() end
      for i, super in ipairs(supers) do
        request_all('textDocument/documentSymbol', { textDocument = { uri = super.uri } }, function(symbols)
          classes[i] = class_at(symbols, super.range.start)
          pending = pending - 1
          if pending == 0 then done() end
        end)
      end
    end)
  end)
end

return M
