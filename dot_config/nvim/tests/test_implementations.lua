local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality
local implementations = require 'custom.implementations'

local function range(line, character) return { start = { line = line, character = character }, ['end'] = { line = line, character = character + 3 } } end

local function loc(uri, line, character) return { uri = uri, range = range(line, character) } end

local T = MiniTest.new_set()

T['supertypes_in_header() reads the Kotlin supertype list, skipping constructor parameters, calls and type arguments'] = function()
  local found = implementations.supertypes_in_header { 'class Foo(val a: Int) : Base(a), Iface<Bar> {' }
  eq(found, {
    { name = 'Base', line = 0, character = 24 },
    { name = 'Iface', line = 0, character = 33 },
  })
end

T['supertypes_in_header() skips the bounds of type parameters'] = function()
  local names = function(header)
    return vim.tbl_map(function(s) return s.name end, implementations.supertypes_in_header { header })
  end
  eq(names 'class Foo<T : Bar> : Base {', { 'Base' })
  eq(names 'class Foo<T extends Bar, U> extends Base<T> implements Iface {', { 'Base', 'Iface' })
end

T['supertypes_in_header() reads the Java extends and implements lists'] = function()
  local found = implementations.supertypes_in_header { 'class Foo extends Base implements Iface, Other {' }
  eq(vim.tbl_map(function(s) return s.name end, found), { 'Base', 'Iface', 'Other' })
end

T['supertypes_in_header() follows a supertype list across lines up to the body'] = function()
  local found = implementations.supertypes_in_header { 'class Foo :', '  Base,', '  Iface {', 'fun publish() {}' }
  eq(found, {
    { name = 'Base', line = 1, character = 2 },
    { name = 'Iface', line = 2, character = 2 },
  })
end

T['supertypes_in_header() finds nothing in a class without supertypes'] = function() eq(implementations.supertypes_in_header { 'class Foo(val a: Int) {' }, {}) end

T['merge() drops duplicate locations and sorts by file, then position'] = function()
  local shared = loc('file:///B.kt', 3, 0)
  local merged = implementations.merge { { loc('file:///A.kt', 9, 2), shared }, { shared, loc('file:///A.kt', 1, 4) } }
  eq(merged, { loc('file:///A.kt', 1, 4), loc('file:///A.kt', 9, 2), shared })
end

T['merge() reads LocationLink results as locations'] = function()
  local link = {
    originSelectionRange = range(0, 0),
    targetUri = 'file:///A.kt',
    targetRange = range(2, 0),
    targetSelectionRange = range(2, 4),
  }
  eq(implementations.merge { { link } }, { loc('file:///A.kt', 2, 4) })
end

local child = helpers.new_child()

T['collect()'] = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.start()
      local file = helpers.tree { ['Foo.kt'] = 'class Foo : Iface {\n\nfun run() {}' .. string.rep('\n', 12), ['Iface.kt'] = '\nfun run()\n' }
      child.cmd('edit ' .. file .. '/Foo.kt')
      child.lua [=[
        -- Fake server: `run` on line 3 is implemented on line 10. References of the interface method are on
        -- line 6, of the implementation on line 13; implementations answer as LocationLink. `Foo` (line 1) extends
        -- `Iface`, whose `run` is on line 2. The header's `Iface` name answers definition only when `overrides` is set.
        local uri = vim.uri_from_bufnr(0)
        local iface_uri = vim.uri_from_fname(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':h') .. '/Iface.kt')
        local function at(l, c) return { uri = uri, range = { start = { line = l, character = c }, ['end'] = { line = l, character = c + 3 } } } end
        local function span(sl, sc, el, ec) return { start = { line = sl, character = sc }, ['end'] = { line = el, character = ec } } end
        local foo = { name = 'Foo', kind = 5, range = span(0, 0, 14, 0), selectionRange = span(0, 6, 0, 9), children = {
          { name = 'run', kind = 6, range = span(2, 0, 2, 12), selectionRange = at(2, 4).range },
        } }
        local iface = { name = 'Iface', kind = 11, range = span(0, 0, 2, 0), selectionRange = span(0, 0, 0, 5), children = {
          { name = 'run', kind = 6, range = span(1, 0, 1, 10), selectionRange = at(1, 4).range },
        } }
        _G.fake = {
          implementation = function() return { { originSelectionRange = at(2, 4).range, targetUri = uri, targetRange = at(9, 0).range, targetSelectionRange = at(9, 4).range } } end,
          definition = function(p)
            if p.position.line == 0 then
              if not _G.fake.overrides then return {} end
              local super = _G.fake.supers and _G.fake.supers[p.position.character]
              return super and { super } or { { uri = iface_uri, range = iface.selectionRange } }
            end
            return { { uri = uri, range = at(9, 4).range } }
          end,
          symbols = function(u) return u == uri and { foo } or u == iface_uri and { iface } or {} end,
          overrides = false,
        }
        vim.lsp.start {
          name = 'impls',
          root_dir = vim.fn.getcwd(),
          cmd = function()
            local closing = false
            return {
              request = function(method, params, callback)
                local handlers = {
                  initialize = function()
                    return { capabilities = { implementationProvider = true, referencesProvider = true, definitionProvider = true, documentSymbolProvider = true, callHierarchyProvider = true } }
                  end,
                  -- The method at the position, then its callers: `run` of Foo is called on line 8, `run` of Iface on line 11.
                  ['textDocument/prepareCallHierarchy'] = function()
                    local p = params.position
                    return { { name = 'run', kind = 6, uri = params.textDocument.uri, range = at(p.line, 0).range, selectionRange = at(p.line, p.character).range } }
                  end,
                  ['callHierarchy/incomingCalls'] = function()
                    local line = params.item.uri == uri and 7 or 10
                    return { { from = { name = 'caller', kind = 6, uri = uri, range = at(line, 0).range, selectionRange = at(line, 0).range }, fromRanges = { at(line, 2).range } } }
                  end,
                  ['textDocument/implementation'] = function() return _G.fake.implementation() end,
                  ['textDocument/definition'] = function() return _G.fake.definition(params) end,
                  ['textDocument/references'] = function() return params.position.line == 2 and { at(5, 4) } or { at(12, 8) } end,
                  ['textDocument/documentSymbol'] = function() return _G.fake.symbols(params.textDocument.uri) end,
                }
                local result = handlers[method] and handlers[method]()
                vim.schedule(function() callback(nil, result) end)
                return true, 1
              end,
              notify = function() return true end,
              is_closing = function() return closing end,
              terminate = function() closing = true end,
            }
          end,
        }
        vim.wait(2000, function() return #vim.lsp.get_clients { bufnr = 0 } > 0 end)
        vim.api.nvim_win_set_cursor(0, { 3, 4 })
      ]=]
    end,
    post_case = function() child.stop() end,
  },
}

T['collect()']['adds the references of each implementation to the interface references'] = function()
  child.lua [=[
    _G.result = nil
    require('custom.implementations').collect(function(locs) _G.result = locs end)
    vim.wait(2000, function() return _G.result ~= nil end)
  ]=]
  local uri = child.lua_get 'vim.uri_from_bufnr(0)'
  eq(child.lua_get '_G.result', {
    { uri = uri, range = range(5, 4) },
    { uri = uri, range = range(12, 8) },
  })
end

T['collect()']['goto_implementation() goes to the definition when the symbol has no implementation (a concrete class)'] = function()
  child.lua [=[
    _G.fake.implementation = function() return {} end
    require('custom.implementations').goto_implementation()
    vim.wait(2000, function() return vim.api.nvim_win_get_cursor(0)[1] == 10 end)
  ]=]
  eq(child.lua_get 'vim.api.nvim_win_get_cursor(0)[1]', 10)
end

T['collect()']['goto_definition() on an override goes to the interface method it overrides'] = function()
  child.lua [=[
    _G.fake.overrides = true
    require('custom.implementations').goto_definition()
    vim.wait(2000, function() return vim.api.nvim_buf_get_name(0):match('Iface%.kt$') ~= nil end)
  ]=]
  eq(child.lua_get "vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')", 'Iface.kt')
  eq(child.lua_get 'vim.api.nvim_win_get_cursor(0)[1]', 2)
end

T['collect()']['goto_implementation() on an override opens the implementations of the interface method, even one'] = function()
  child.lua [=[
    _G.fake.overrides = true
    _G.picked = nil
    require('custom.implementations').pick = function(locations, title) _G.picked = { locations = locations, title = title } end
    require('custom.implementations').goto_implementation()
    vim.wait(2000, function() return _G.picked ~= nil end)
  ]=]
  eq(child.lua_get '#_G.picked.locations', 1)
  eq(child.lua_get '_G.picked.title', 'Implementations of run')
  eq(child.lua_get "vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')", 'Foo.kt')
end

T['collect()']['goto_implementation() on an override without implementations goes to the interface method'] = function()
  child.lua [=[
    _G.fake.overrides = true
    _G.fake.implementation = function() return {} end
    require('custom.implementations').goto_implementation()
    vim.wait(2000, function() return vim.api.nvim_buf_get_name(0):match('Iface%.kt$') ~= nil end)
  ]=]
  eq(child.lua_get "vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')", 'Iface.kt')
  eq(child.lua_get 'vim.api.nvim_win_get_cursor(0)[1]', 2)
end

T['collect()']['grc on an override lists the callers of the overridden method too'] = function()
  child.lua [=[
    _G.fake.overrides = true
    _G.picked = nil
    require('custom.implementations').pick = function(locations, title) _G.picked = { locations = locations, title = title } end
  ]=]
  child.type_keys 'grc'
  child.lua [=[ vim.wait(2000, function() return _G.picked ~= nil end) ]=]
  local uri = child.lua_get 'vim.uri_from_bufnr(0)'
  eq(child.lua_get '_G.picked.locations', { { uri = uri, range = range(7, 2) }, { uri = uri, range = range(10, 2) } })
  eq(child.lua_get '_G.picked.title', 'Incoming calls of run, with the overridden method')
end

T['collect()']['grc elsewhere is the plain incoming calls picker'] = function()
  child.lua [=[
    _G.builtin = false
    require('telescope.builtin').lsp_incoming_calls = function() _G.builtin = true end
  ]=]
  child.type_keys 'grc'
  child.lua [=[ vim.wait(2000, function() return _G.builtin end) ]=]
  eq(child.lua_get '_G.builtin', true)
end

T['collect()']['grs on an override goes to the method it overrides, from its name or its body'] = function()
  child.lua [=[ _G.fake.overrides = true ]=]
  local foo = child.lua_get 'vim.api.nvim_get_current_buf()'
  for _, col in ipairs { 4, 10 } do
    child.cmd('buffer ' .. foo)
    child.lua('vim.api.nvim_win_set_cursor(0, { 3, ' .. col .. ' })')
    child.type_keys 'grs'
    child.lua [=[ vim.wait(2000, function() return vim.api.nvim_buf_get_name(0):match('Iface%.kt$') ~= nil end) ]=]
    eq(
      { col, child.lua_get "vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')", child.lua_get 'vim.api.nvim_win_get_cursor(0)[1]' },
      { col, 'Iface.kt', 2 }
    )
  end
end

T['collect()']['grs on a method that overrides nothing says so and stays'] = function()
  child.cmd 'messages clear'
  child.type_keys 'grs'
  child.lua [=[ vim.wait(2000, function() return vim.fn.execute('messages'):match('overrides no method') ~= nil end) ]=]
  eq(child.lua_get "vim.fn.execute('messages'):match('run overrides no method') ~= nil", true)
  eq(child.lua_get "vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')", 'Foo.kt')
end

T['collect()']['grs in a class outside its methods goes to its supertype'] = function()
  child.lua [=[
    _G.fake.overrides = true
    vim.api.nvim_win_set_cursor(0, { 1, 7 })
  ]=]
  child.type_keys 'grs'
  child.lua [=[ vim.wait(2000, function() return vim.api.nvim_buf_get_name(0):match('Iface%.kt$') ~= nil end) ]=]
  eq(child.lua_get "vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')", 'Iface.kt')
  eq(child.lua_get 'vim.api.nvim_win_get_cursor(0)[1]', 1)
end

T['collect()']['grs in a class with several supertypes opens them in a picker'] = function()
  child.lua [=[
    _G.fake.overrides = true
    local uri = vim.uri_from_bufnr(0)
    local function at(l, c) return { uri = uri, range = { start = { line = l, character = c }, ['end'] = { line = l, character = c + 3 } } } end
    _G.fake.supers = { [12] = at(20, 0), [19] = at(30, 0) }
    vim.api.nvim_buf_set_lines(0, 0, 1, false, { 'class Foo : Iface, Other {' })
    vim.api.nvim_win_set_cursor(0, { 1, 7 })
    _G.picked = nil
    require('custom.implementations').pick = function(locations, title) _G.picked = { locations = locations, title = title } end
  ]=]
  child.type_keys 'grs'
  child.lua [=[ vim.wait(2000, function() return _G.picked ~= nil end) ]=]
  local uri = child.lua_get 'vim.uri_from_bufnr(0)'
  eq(child.lua_get '_G.picked.locations', { { uri = uri, range = range(20, 0) }, { uri = uri, range = range(30, 0) } })
  eq(child.lua_get '_G.picked.title', 'Supertypes of Foo')
end

T['collect()']['grR is mapped in LSP buffers next to grr, and grr keeps its own mapping'] = function()
  child.lua [=[ _G.grR = vim.fn.maparg('grR', 'n', false, true) ]=]
  eq(child.lua_get '_G.grR.buffer', 1)
  eq(child.lua_get '_G.grR.desc', '[G]oto [R]eferences incl. implementations')
  eq(child.lua_get "vim.fn.maparg('grr', 'n', false, true).desc", '[G]oto [R]eferences')
end

return T
