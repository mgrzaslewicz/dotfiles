-- `<M-t>T`: the type hierarchy of the type around the cursor as a tree (IntelliJ Ctrl+H), in a split below. Tests:
-- tests/test_types.lua; replayed on jdtls in tests/test_replay_gradle_java.lua.
--
--   Foo  Foo.kt
--   ▾ ↑ Base  Base.kt        all the supertypes, unfolded: the header's, then theirs
--       ↑ Root  Root.kt
--   ▾ ↑ Iface  Iface.kt      each unfolded to its direct subtypes too: the siblings of the type, the type among them
--     ▸ ↓ Foo  Foo.kt
--     ▸ ↓ Bar  Bar.kt
--   ▾ ↓ Sub  Sub.kt          the subtypes, unfolded three levels down: deeper ones are asked for when unfolded
--     ▾ ↓ SubSub  SubSub.kt
--       ▸ ↓ Deep  Deep.kt
--
-- `<CR>` goes to the type in the window the tree was opened from (the tree stays), `<Tab>` folds or unfolds, `l`
-- unfolds, `h` folds (or goes to the parent), `q` closes. A supertype's direct subtypes are listed below its own
-- supertypes, each folded: unfolding one asks for its subtypes.
--
-- Built from the same requests as `<M-t>H` and `<M-t>h` (custom/types.lua), not from LSP type hierarchy, which
-- kotlin_lsp answers with nothing: supertypes are the names in the class header, resolved by go-to-definition;
-- subtypes are textDocument/implementation at the type's name. Servers answer that transitively (jdtls lists every
-- subtype below), so a subtype is kept only when its own header names the type; one whose header cannot be read
-- (outside the project) is kept. An implementation that is no declared type (an anonymous class, an object
-- expression) is listed as `anonymous in <enclosing type>`, without children.
--
-- Known limit: as for `<M-t>H`, the supertypes of a type outside the project (`jdt://`, `jar:`) are not read.

local implementations = require 'custom.implementations'
local types = require 'custom.types'

local M = {}

local MAX_DEPTH = 20
-- Levels of subtypes the tree opens with, unfolded; deeper ones are loaded on unfolding.
local SUBTYPE_LEVELS = 3

-- The tree buffer has no server: requests go to the servers of the buffer the tree was opened from.
local source_buf = 0

local function request_all(method, params, callback) return implementations.request_all(method, params, callback, source_buf) end

local function file_of(uri) return vim.fn.fnamemodify(vim.uri_to_fname(uri), ':t') end

--- A node for the type declared by `class` (a symbol, or nil when unknown) at `location`.
local function node(location, class, dir, name)
  return { uri = location.uri, range = class and class.selectionRange or location.range, class = class, dir = dir, name = class and class.name or name }
end

--- Calls back with the class symbols at `locations` (nil where none is declared) and their enclosing ones.
local function classes_at(locations, callback)
  local pending, declared, enclosing = #locations, {}, {}
  if pending == 0 then return callback(declared, enclosing) end
  for i, location in ipairs(locations) do
    request_all('textDocument/documentSymbol', { textDocument = { uri = location.uri } }, function(symbols)
      declared[i] = types.class_declared_at(symbols, location.range.start)
      enclosing[i] = implementations.enclosing_class(symbols, location.range.start)
      pending = pending - 1
      if pending == 0 then callback(declared, enclosing) end
    end)
  end
end

--- Calls back with the direct supertypes of `n`.
local function supertypes_of(n, callback)
  if not n.class then return callback {} end
  types.direct_supertypes(n.uri, n.class, function(supers)
    classes_at(supers, function(declared)
      local out = {}
      for i, super in ipairs(supers) do
        table.insert(out, node(super, declared[i], 'super', super.name or file_of(super.uri)))
      end
      callback(out)
    end)
  end, source_buf)
end

local function same_place(location, n) return location.uri == n.uri and location.range.start.line == n.range.start.line end

--- Calls back with the direct subtypes of `n`, by name.
local function subtypes_of(n, callback)
  request_all('textDocument/implementation', { textDocument = { uri = n.uri }, position = n.range.start }, function(found)
    local candidates = implementations.merge { found }
    classes_at(candidates, function(declared, enclosing)
      local out, pending = {}, #candidates
      local function done()
        pending = pending - 1
        if pending > 0 then return end
        local list = vim.tbl_values(out)
        table.sort(list, function(a, b) return a.order < b.order end)
        callback(vim.tbl_map(function(entry) return entry.node end, list))
      end
      if pending == 0 then return callback {} end
      for i, candidate in ipairs(candidates) do
        local class = declared[i]
        if not class then
          local anonymous = node(candidate, nil, 'sub', ('anonymous in %s'):format(enclosing[i] and enclosing[i].name or file_of(candidate.uri)))
          anonymous.children, anonymous.complete = {}, true
          out[i] = { node = anonymous, order = '~' .. anonymous.name }
          done()
        else
          types.direct_supertypes(candidate.uri, class, function(supers)
            local direct = #supers == 0 or vim.iter(supers):any(function(s) return same_place(s, n) end)
            if direct then out[i] = { node = node(candidate, class, 'sub'), order = class.name } end
            done()
          end, source_buf)
        end
      end
    end)
  end)
end

--- Loads the children of `n` (once) and calls back: a subtype's direct subtypes; a supertype's, its own supertypes
--- loaded already, are its direct subtypes (the siblings of the type, the type among them), appended below them.
local function load(n, callback)
  if n.complete then return callback() end
  subtypes_of(n, function(subs)
    n.children = vim.list_extend(n.children or {}, subs)
    n.complete = true
    callback()
  end)
end

--- Loads the subtypes of `nodes` (at `level`, 1 for the direct subtypes) down to SUBTYPE_LEVELS, unfolded, then calls
--- back.
local function load_subtypes(nodes, level, callback)
  local pending = #nodes
  if pending == 0 or level >= SUBTYPE_LEVELS then return callback() end
  local function done()
    pending = pending - 1
    if pending == 0 then callback() end
  end
  for _, n in ipairs(nodes) do
    if n.complete then
      done()
    else
      load(n, function()
        n.open = #n.children > 0
        load_subtypes(n.children, level + 1, done)
      end)
    end
  end
end

--- Adds to each supertype in `nodes` (and in theirs, up the hierarchy) its direct subtypes, unfolded, then calls back.
local function load_siblings(nodes, callback)
  local supers = {}
  local function collect(list)
    for _, n in ipairs(list) do
      if n.dir == 'super' then
        table.insert(supers, n)
        collect(n.children or {})
      end
    end
  end
  collect(nodes)
  local pending = #supers
  if pending == 0 then return callback() end
  for _, n in ipairs(supers) do
    load(n, function()
      n.open = #n.children > 0
      pending = pending - 1
      if pending == 0 then callback() end
    end)
  end
end

--- Loads all the supertypes of `n`, unfolded, then calls back.
local function load_supertypes(n, depth, callback)
  if depth >= MAX_DEPTH then
    n.children = n.children or {}
    return callback()
  end
  supertypes_of(n, function(children)
    n.children, n.open = children, #children > 0
    local pending = #children
    if pending == 0 then return callback() end
    for _, child in ipairs(children) do
      load_supertypes(child, depth + 1, function()
        pending = pending - 1
        if pending == 0 then callback() end
      end)
    end
  end)
end

--- The lines of the tree under `root`, and the node of each line.
---@return string[], table[]
function M.render(root)
  local lines, nodes = { ('%s  %s'):format(root.name, file_of(root.uri)) }, { root }
  local function walk(children, depth)
    for _, n in ipairs(children) do
      local marker = (n.complete and #n.children == 0) and ' ' or (n.open and '▾' or '▸')
      local arrow = n.dir == 'super' and '↑' or '↓'
      table.insert(lines, ('%s%s %s %s  %s'):format(string.rep('  ', depth), marker, arrow, n.name, file_of(n.uri)))
      table.insert(nodes, n)
      n.parent_depth = depth
      if n.open then walk(n.children, depth + 1) end
    end
  end
  walk(root.supers, 0)
  walk(root.subs, 0)
  return lines, nodes
end

local ns = vim.api.nvim_create_namespace 'custom.type_hierarchy'

local function draw(state)
  local lines, nodes = M.render(state.root)
  state.nodes = nodes
  local buf = state.buf
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, line in ipairs(lines) do
    local file = file_of(nodes[i].uri)
    vim.api.nvim_buf_set_extmark(buf, ns, i - 1, #line - #file, { end_col = #line, hl_group = 'Comment' })
  end
end

local function current(state) return state.nodes[vim.api.nvim_win_get_cursor(0)[1]] end

local function unfold(state, n)
  if n == state.root or (n.complete and #n.children == 0) then return end
  load(n, function()
    n.open = #n.children > 0
    draw(state)
  end)
end

local function fold(state, n)
  if n.open then
    n.open = false
    return draw(state)
  end
  -- Folded already: to its parent, the nearest line above with less indent.
  local row = vim.api.nvim_win_get_cursor(0)[1]
  for r = row - 1, 1, -1 do
    local above = state.nodes[r]
    if above == state.root or (above.parent_depth or 0) < (n.parent_depth or 0) then return vim.api.nvim_win_set_cursor(0, { r, 0 }) end
  end
end

local function jump(state, n)
  local win = vim.api.nvim_win_is_valid(state.source) and state.source or vim.fn.win_getid(vim.fn.winnr '#')
  vim.api.nvim_set_current_win(win)
  vim.cmd "normal! m'"
  vim.lsp.util.show_document({ uri = n.uri, range = n.range }, 'utf-16', { focus = true })
end

local function open(root)
  local state = { root = root, source = vim.api.nvim_get_current_win() }
  vim.cmd 'botright 12split'
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, state.buf)
  vim.bo[state.buf].bufhidden = 'wipe'
  vim.bo[state.buf].filetype = 'typehierarchy'
  vim.wo.winbar = (' Type hierarchy of %s   <CR> go  <Tab> fold  q close'):format(root.name)
  vim.wo.number, vim.wo.relativenumber, vim.wo.signcolumn, vim.wo.wrap = false, false, 'no', false
  draw(state)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local function map(lhs, fn, desc)
    vim.keymap.set('n', lhs, function() fn(state, current(state)) end, { buffer = state.buf, desc = 'Type hierarchy: ' .. desc, nowait = true })
  end
  map('<CR>', jump, 'go to the type')
  map('<Tab>', function(s, n)
    if n.open then return fold(s, n) end
    unfold(s, n)
  end, 'fold or unfold')
  map('l', unfold, 'unfold')
  map('h', fold, 'fold, or to the parent')
  map('q', function() vim.api.nvim_win_close(0, true) end, 'close')
end

--- Opens the type hierarchy of the type around the cursor (`<M-t>T`).
function M.show()
  source_buf = vim.api.nvim_get_current_buf()
  types.type_around_cursor(function(here, name, class)
    local root = { uri = here.uri, range = here.range, class = class, name = name, dir = 'super' }
    local pending = 2
    local function done()
      pending = pending - 1
      if pending > 0 then return end
      if #root.supers + #root.subs == 0 then return vim.notify(('%s has no supertypes or subtypes'):format(name), vim.log.levels.INFO) end
      open(root)
    end
    load_supertypes(root, 0, function()
      root.supers = root.children
      load_siblings(root.supers, done)
    end)
    subtypes_of(root, function(subs)
      root.subs = subs
      load_subtypes(subs, 1, done)
    end)
  end)
end

return M
