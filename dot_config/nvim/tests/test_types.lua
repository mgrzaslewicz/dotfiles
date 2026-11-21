-- `<M-t>`: actions on the type around the cursor (lua/custom/types.lua), from anywhere in it.
local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

-- Foo.kt: `class Foo : Base(), Iface` (line 5, after a doc comment and an annotation) with a method `run` (lines 6-8);
-- `Base : Root`; `Sub` extends Foo. A table-driven fake server: `_G.fake.<method>[uri:line:character]` answers a
-- request at that position, `_G.fake.symbols[uri]` the documentSymbol tree.
local files = {
  ['Foo.kt'] = { 'package x', '', '/** Foo. */', '@Deprecated("x")', 'class Foo : Base(), Iface {', '    fun run() {', '        val a = 1', '    }', '}' },
  ['Base.kt'] = { 'open class Base : Root {', '}' },
  ['Root.kt'] = { 'open class Root {', '}' },
  ['Iface.kt'] = { 'interface Iface {', '}' },
  ['Sub.kt'] = { 'class Sub : Foo() {', '}' },
  ['SubSub.kt'] = { 'class SubSub : Sub() {', '}' },
  ['FooTest.kt'] = { 'class FooTest {', '}' },
  ['UsesTest.kt'] = { 'class UsesTest {', '', '  val a = Foo()', '', '', '  val b = Foo()', '}' },
  ['OtherTest.kt'] = { 'class OtherTest {', '  val a = Foo()', '}' },
}

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      -- The test child has no clipboard tool: a provider that keeps `+` in memory (for <M-t>y).
      child.start {
        '--cmd',
        "lua vim.g.clipboard = { name = 'test', copy = { ['+'] = function(l) _G.clip = l end, ['*'] = function(l) _G.clip = l end }, "
          .. "paste = { ['+'] = function() return _G.clip or {} end, ['*'] = function() return _G.clip or {} end } }",
      }
      local tree = {}
      for name, lines in pairs(files) do
        tree[name] = table.concat(lines, '\n')
      end
      local dir = helpers.tree(tree)
      child.cmd('edit ' .. dir .. '/Foo.kt')
      child.lua [=[
        local function span(sl, sc, el, ec) return { start = { line = sl, character = sc }, ['end'] = { line = el, character = ec } } end
        local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':h')
        local function u(name) return vim.uri_from_fname(dir .. '/' .. name) end
        _G.u = u
        local function class(name, kind, line, col, last, children) return { name = name, kind = kind, range = span(line, 0, last, 1), selectionRange = span(line, col, line, col + #name), children = children or {} } end
        _G.fake = {
          symbols = {
            [u 'Foo.kt'] = { class('Foo', 5, 4, 6, 8, { { name = 'run', kind = 6, range = span(5, 4, 7, 5), selectionRange = span(5, 8, 5, 11) } }) },
            [u 'Base.kt'] = { class('Base', 5, 0, 11, 1) },
            [u 'Root.kt'] = { class('Root', 5, 0, 11, 1) },
            [u 'Iface.kt'] = { class('Iface', 11, 0, 10, 1) },
            [u 'Sub.kt'] = { class('Sub', 5, 0, 6, 1) },
          },
          ['textDocument/definition'] = {
            [u 'Foo.kt' .. ':4:12'] = { { uri = u 'Base.kt', range = span(0, 11, 0, 15) } },
            [u 'Foo.kt' .. ':4:20'] = { { uri = u 'Iface.kt', range = span(0, 10, 0, 15) } },
            [u 'Base.kt' .. ':0:18'] = { { uri = u 'Root.kt', range = span(0, 11, 0, 15) } },
          },
          ['textDocument/implementation'] = {
            [u 'Foo.kt' .. ':4:6'] = { { uri = u 'Sub.kt', range = span(0, 6, 0, 9) } },
          },
          ['textDocument/references'] = {},
        }
        vim.lsp.start {
          name = 'types',
          root_dir = vim.fn.getcwd(),
          cmd = function()
            local closing = false
            return {
              request = function(method, params, callback)
                local result
                if method == 'initialize' then
                  result = { capabilities = { definitionProvider = true, implementationProvider = true, referencesProvider = true, documentSymbolProvider = true } }
                elseif method == 'textDocument/documentSymbol' then
                  result = _G.fake.symbols[params.textDocument.uri] or {}
                elseif _G.fake[method] then
                  local p = params.position
                  result = _G.fake[method][('%s:%d:%d'):format(params.textDocument.uri, p.line, p.character)] or {}
                  if type(result) == 'function' then result = result(params) end
                end
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
        vim.api.nvim_win_set_cursor(0, { 7, 8 })
        _G.picked = nil
        require('custom.implementations').pick = function(locations, title, opts) _G.picked = { locations = locations, title = title, keep_order = opts and opts.keep_order } end
      ]=]
    end,
    post_case = function() child.stop() end,
  },
}

-- The picked locations as `file:line` (0-based).
local function picked()
  child.lua [=[ vim.wait(2000, function() return _G.picked ~= nil end) ]=]
  return child.lua_get [[{ title = _G.picked.title, keep_order = _G.picked.keep_order, locations = vim.tbl_map(function(l) return vim.fn.fnamemodify(vim.uri_to_fname(l.uri), ':t') .. ':' .. l.range.start.line end, _G.picked.locations) }]]
end

T['<M-t>s in a method of the type lists the supertypes its header names'] = function()
  child.type_keys '<M-t>s'
  eq(picked(), { title = 'Supertypes of Foo', locations = { 'Base.kt:0', 'Iface.kt:0' } })
end

T['<M-t>H lists all the supertypes, up the hierarchy, nearest first'] = function()
  child.type_keys '<M-t>H'
  eq(picked(), { title = 'Supertypes of Foo, up the hierarchy', keep_order = true, locations = { 'Base.kt:0', 'Iface.kt:0', 'Root.kt:0' } })
end

T['<M-t>h lists the subtypes, in a picker even for one'] = function()
  child.type_keys '<M-t>h'
  eq(picked(), { title = 'Subtypes of Foo', locations = { 'Sub.kt:0' } })
end

T['<M-t>i lists the implementations of the type, like gri on its name'] = function()
  child.type_keys '<M-t>i'
  eq(picked(), { title = 'Implementations of Foo', locations = { 'Sub.kt:0' } })
end

T['<M-t>i on a type without implementations goes to its name, where gri stays'] = function()
  child.lua [=[ _G.fake['textDocument/implementation'] = {} ]=]
  child.type_keys '<M-t>i'
  child.lua [=[ vim.wait(2000, function() return vim.api.nvim_win_get_cursor(0)[1] == 5 end) ]=]
  eq(child.lua_get 'vim.api.nvim_win_get_cursor(0)', { 5, 6 })
end

T['<M-t>r lists the usages of the type, its declaration left out'] = function()
  child.lua [=[
    local function at(name, line) return { uri = _G.u(name), range = { start = { line = line, character = 0 }, ['end'] = { line = line, character = 3 } } } end
    _G.fake['textDocument/references'][_G.u 'Foo.kt' .. ':4:6'] = function(params)
      local refs = { at('Sub.kt', 0), at('Foo.kt', 6) }
      if params.context.includeDeclaration then table.insert(refs, at('Foo.kt', 4)) end
      return refs
    end
  ]=]
  child.type_keys '<M-t>r'
  eq(picked(), { title = 'Usages of Foo', locations = { 'Foo.kt:6', 'Sub.kt:0' } })
end

T['<M-t>m lists the members of the type, in file order, a nested type without its own members'] = function()
  child.lua [=[
    local function span(sl, sc, el, ec) return { start = { line = sl, character = sc }, ['end'] = { line = el, character = ec } } end
    local foo = _G.fake.symbols[_G.u 'Foo.kt'][1]
    table.insert(foo.children, 1, { name = 'count', kind = 8, range = span(5, 4, 5, 20), selectionRange = span(5, 8, 5, 13) })
    table.insert(foo.children, { name = 'Inner', kind = 5, range = span(7, 4, 7, 20), selectionRange = span(7, 10, 7, 15), children = {
      { name = 'deep', kind = 6, range = span(7, 12, 7, 18), selectionRange = span(7, 12, 7, 16) },
    } })
    require('custom.implementations').pick = function(locations, title, opts)
      _G.picked = { locations = locations, title = title, keep_order = opts and opts.keep_order, names = vim.tbl_map(function(l) return l.name end, locations), columns = opts and opts.columns }
    end
  ]=]
  child.type_keys '<M-t>m'
  child.lua [=[ vim.wait(2000, function() return _G.picked ~= nil end) ]=]
  eq(
    child.lua_get '{ _G.picked.title, _G.picked.names, _G.picked.keep_order, _G.picked.columns }',
    { 'Members of Foo', { 'count', 'run', 'Inner' }, true, true }
  )
  eq(child.lua_get 'vim.tbl_map(function(l) return l.range.start.line end, _G.picked.locations)', { 5, 5, 7 })
end

T['<M-t>n renames the type, from its name'] = function()
  child.lua [=[
    _G.ran = nil
    require('custom.refactor').run = function(name) _G.ran = { name, vim.api.nvim_win_get_cursor(0) } end
  ]=]
  child.type_keys '<M-t>n'
  child.lua [=[ vim.wait(2000, function() return _G.ran ~= nil end) ]=]
  eq(child.lua_get '_G.ran', { 'rename', { 5, 6 } })
  child.type_keys '<C-o>'
  eq(child.lua_get 'vim.api.nvim_win_get_cursor(0)[1]', 7)
end

T['<M-t>v selects the type linewise, with its annotation and doc comment'] = function()
  child.type_keys '<M-t>v'
  child.lua [=[ vim.wait(2000, function() return vim.fn.mode() == 'V' end) ]=]
  eq({ child.lua_get 'vim.fn.mode()', child.lua_get "vim.fn.line('v')", child.lua_get "vim.fn.line('.')" }, { 'V', 3, 9 })
end

T['<M-t>y copies the qualified name of the type, from inside a method'] = function()
  child.type_keys '<M-t>y'
  child.lua [=[ vim.wait(2000, function() return vim.fn.getreg('+') ~= '' end) ]=]
  eq(child.lua_get "vim.fn.getreg('+')", 'x.Foo')
end

-- `<M-t>t` / `<M-t>u`: the test files using the type (its references in test files, each at the first one), its
-- test counterpart (FooTest.kt) first when it exists.
local function used_in(refs, counterpart)
  child.lua(([=[
    local refs, counterpart = %s, %s
    _G.fake['textDocument/references'][_G.u 'Foo.kt' .. ':4:6'] = function(params)
      if params.context.includeDeclaration then return {} end
      return vim.tbl_map(function(r) return { uri = _G.u(r[1]), range = { start = { line = r[2], character = 2 }, ['end'] = { line = r[2], character = 5 } } } end, refs)
    end
    require('custom.jvm.test_pair').counterpart = function() return counterpart and vim.uri_to_fname(_G.u(counterpart)) end
  ]=]):format(vim.inspect(refs), vim.inspect(counterpart)))
end

T['<M-t>t lists the test files using the type, each at its first use'] = function()
  used_in { { 'Sub.kt', 0 }, { 'UsesTest.kt', 5 }, { 'UsesTest.kt', 2 }, { 'OtherTest.kt', 1 } }
  child.type_keys '<M-t>t'
  eq(picked(), { title = 'Tests of Foo', keep_order = true, locations = { 'OtherTest.kt:1', 'UsesTest.kt:2' } })
end

T['<M-t>t puts the test counterpart first'] = function()
  used_in({ { 'UsesTest.kt', 2 } }, 'FooTest.kt')
  child.type_keys '<M-t>t'
  eq(picked(), { title = 'Tests of Foo', keep_order = true, locations = { 'FooTest.kt:0', 'UsesTest.kt:2' } })
end

T['<M-t>t goes straight to the only test file'] = function()
  used_in { { 'OtherTest.kt', 1 } }
  child.type_keys '<M-t>t'
  child.lua [=[ vim.wait(2000, function() return vim.api.nvim_buf_get_name(0):match('OtherTest%.kt$') ~= nil end) ]=]
  eq(child.lua_get 'vim.api.nvim_win_get_cursor(0)', { 2, 2 })
end

T['<M-t>t says so when no test uses the type'] = function()
  used_in { { 'Sub.kt', 0 } }
  child.cmd 'messages clear'
  child.type_keys '<M-t>t'
  child.lua [=[ vim.wait(2000, function() return vim.fn.execute('messages'):match('No tests use Foo') ~= nil end) ]=]
  eq(child.lua_get "vim.fn.execute('messages'):match('No tests use Foo') ~= nil", true)
end

T['<M-t>u runs those test files through neotest'] = function()
  used_in({ { 'UsesTest.kt', 2 } }, 'FooTest.kt')
  child.lua [=[
    _G.ran = {}
    package.loaded.neotest = { run = { run = function(path) table.insert(_G.ran, vim.fn.fnamemodify(path, ':t')) end } }
  ]=]
  child.type_keys '<M-t>u'
  child.lua [=[ vim.wait(2000, function() return #_G.ran == 2 end) ]=]
  eq(child.lua_get '_G.ran', { 'FooTest.kt', 'UsesTest.kt' })
end

T['<M-t>M lists the members of the type and of its supertypes, nearest first, an override once'] = function()
  child.lua [=[
    local function span(sl, sc, el, ec) return { start = { line = sl, character = sc }, ['end'] = { line = el, character = ec } } end
    local function member(name, kind, line) return { name = name, kind = kind, range = span(line, 2, line, 20), selectionRange = span(line, 6, line, 6 + #name) } end
    _G.fake.symbols[_G.u 'Base.kt'][1].children = { member('count', 8, 0), member('run', 6, 0) }
    _G.fake.symbols[_G.u 'Iface.kt'][1].children = { member('greet()', 6, 0) }
    _G.fake.symbols[_G.u 'Root.kt'][1].children = { member('id', 8, 0) }
    require('custom.implementations').pick = function(locations, title, opts)
      _G.picked = { title = title, keep_order = opts and opts.keep_order, columns = opts and opts.columns, names = vim.tbl_map(function(l) return l.name end, locations) }
    end
  ]=]
  child.type_keys '<M-t>M'
  child.lua [=[ vim.wait(2000, function() return _G.picked ~= nil end) ]=]
  eq(child.lua_get '_G.picked', {
    title = 'Members of Foo, with its supertypes',
    keep_order = true,
    columns = true,
    names = { 'Foo.run', 'Base.count', 'Iface.greet', 'Root.id' },
  })
end

T['<M-t> works in a Kotlin object'] = function()
  child.lua [=[
    local function span(sl, sc, el, ec) return { start = { line = sl, character = sc }, ['end'] = { line = el, character = ec } } end
    _G.fake.symbols[_G.u 'Foo.kt'] = { { name = 'Registry', kind = 19, range = span(4, 0, 8, 1), selectionRange = span(4, 7, 4, 15), children = {
      { name = 'run', kind = 6, range = span(5, 4, 7, 5), selectionRange = span(5, 8, 5, 11) },
    } } }
  ]=]
  child.type_keys '<M-t>m'
  eq(picked(), { title = 'Members of Registry', keep_order = true, locations = { 'Foo.kt:5' } })
end

T['<M-t> outside any type says so'] = function()
  child.lua [=[ vim.api.nvim_win_set_cursor(0, { 1, 0 }) ]=]
  child.cmd 'messages clear'
  child.type_keys '<M-t>h'
  child.lua [=[ vim.wait(2000, function() return vim.fn.execute('messages'):match('Not in a type') ~= nil end) ]=]
  eq(child.lua_get "vim.fn.execute('messages'):match('Not in a type') ~= nil", true)
end

-- `<M-t>T`: the server answers implementations transitively (as jdtls does): Foo's are Sub and SubSub, Sub's is SubSub;
-- the tree keeps the direct ones, read from their headers. Foo also has an anonymous subtype in `run`.
local function hierarchy_fake()
  child.lua [=[
    local function span(sl, sc, el, ec) return { start = { line = sl, character = sc }, ['end'] = { line = el, character = ec } } end
    local u = _G.u
    _G.fake.symbols[u 'SubSub.kt'] = { { name = 'SubSub', kind = 5, range = span(0, 0, 1, 1), selectionRange = span(0, 6, 0, 12), children = {} } }
    _G.fake['textDocument/definition'][u 'Sub.kt' .. ':0:12'] = { { uri = u 'Foo.kt', range = span(4, 6, 4, 9) } }
    _G.fake['textDocument/definition'][u 'SubSub.kt' .. ':0:15'] = { { uri = u 'Sub.kt', range = span(0, 6, 0, 9) } }
    _G.fake['textDocument/implementation'][u 'Foo.kt' .. ':4:6'] = {
      { uri = u 'SubSub.kt', range = span(0, 6, 0, 12) },
      { uri = u 'Sub.kt', range = span(0, 6, 0, 9) },
      { uri = u 'Foo.kt', range = span(6, 16, 6, 16) },
    }
    _G.fake['textDocument/implementation'][u 'Sub.kt' .. ':0:6'] = { { uri = u 'SubSub.kt', range = span(0, 6, 0, 12) } }
  ]=]
end

local function tree_lines()
  child.lua [=[ vim.wait(2000, function() return vim.bo.filetype == 'typehierarchy' end) ]=]
  return child.lua_get 'vim.api.nvim_buf_get_lines(0, 0, -1, false)'
end

local function tree_on(text) child.lua(('vim.fn.search(%q)'):format('\\V' .. text)) end

T['<M-t>T'] = MiniTest.new_set()

T['<M-t>T']['opens the type hierarchy: all the supertypes above, the direct subtypes below, folded'] = function()
  hierarchy_fake()
  child.type_keys '<M-t>T'
  eq(tree_lines(), {
    'Foo  Foo.kt',
    '▾ ↑ Base  Base.kt',
    '    ↑ Root  Root.kt',
    '  ↑ Iface  Iface.kt',
    '▸ ↓ Sub  Sub.kt',
    '  ↓ anonymous in Foo  Foo.kt',
  })
  eq(child.lua_get 'vim.api.nvim_win_get_cursor(0)', { 1, 0 })
  eq(child.lua_get 'vim.wo.winbar:match("Type hierarchy of Foo") ~= nil', true)
end

T['<M-t>T']['<Tab> unfolds a subtype, loading its direct subtypes, and folds it again'] = function()
  hierarchy_fake()
  child.type_keys '<M-t>T'
  tree_lines()
  tree_on '↓ Sub '
  child.type_keys '<Tab>'
  child.lua [=[ vim.wait(2000, function() return vim.api.nvim_buf_line_count(0) == 7 end) ]=]
  eq(child.lua_get 'vim.api.nvim_buf_get_lines(0, 4, -1, false)', { '▾ ↓ Sub  Sub.kt', '  ▸ ↓ SubSub  SubSub.kt', '  ↓ anonymous in Foo  Foo.kt' })
  child.type_keys '<Tab>'
  eq(child.lua_get 'vim.api.nvim_buf_get_lines(0, 4, -1, false)', { '▸ ↓ Sub  Sub.kt', '  ↓ anonymous in Foo  Foo.kt' })
end

T['<M-t>T']['<CR> goes to the type in the window the tree was opened from, the tree kept'] = function()
  hierarchy_fake()
  local source = child.lua_get 'vim.api.nvim_get_current_win()'
  child.type_keys '<M-t>T'
  tree_lines()
  tree_on '↑ Iface'
  child.type_keys '<CR>'
  child.lua [=[ vim.wait(2000, function() return vim.api.nvim_buf_get_name(0):match('Iface%.kt$') ~= nil end) ]=]
  eq(child.lua_get 'vim.api.nvim_get_current_win()', source)
  eq(child.lua_get 'vim.api.nvim_win_get_cursor(0)', { 1, 10 })
  eq(child.lua_get '#vim.api.nvim_list_wins()', 2)
end

T['<M-t>T']['q closes the tree'] = function()
  hierarchy_fake()
  child.type_keys '<M-t>T'
  tree_lines()
  child.type_keys 'q'
  eq(child.lua_get '#vim.api.nvim_list_wins()', 1)
end

T['<M-t>T']['says so for a type with neither supertypes nor subtypes'] = function()
  child.lua [=[
    vim.cmd.edit(vim.uri_to_fname(_G.u 'Root.kt'))
    vim.lsp.buf_attach_client(0, vim.lsp.get_clients({ name = 'types' })[1].id)
    vim.wait(2000, function() return #vim.lsp.get_clients { bufnr = 0 } > 0 end)
  ]=]
  child.cmd 'messages clear'
  child.type_keys '<M-t>T'
  child.lua [=[ vim.wait(2000, function() return vim.fn.execute('messages'):match('Root has no supertypes or subtypes') ~= nil end) ]=]
  eq(child.lua_get "vim.fn.execute('messages'):match('Root has no supertypes or subtypes') ~= nil", true)
end

T['<M-t> maps are set in LSP buffers with their descs'] = function()
  eq(
    vim.tbl_map(
      function(k) return child.lua_get(("vim.fn.maparg('<M-t>%s', 'n', false, true).desc"):format(k)) end,
      { 's', 'H', 'h', 'i', 'r', 'm', 'n', 'v', 'y', 't', 'u', 'M', 'T' }
    ),
    {
      'Type: [S]upertypes',
      'Type: [H]ierarchy up (supertypes)',
      'Type: [h]ierarchy down (subtypes)',
      'Type: [I]mplementations',
      'Type: usages ([R]eferences)',
      'Type: [M]embers',
      'Type: re[n]ame',
      'Type: select ([V]isual)',
      'Type: cop[y] reference',
      'Type: [T]ests',
      'Type: r[u]n its tests',
      'Type: [M]embers with supertypes',
      'Type: hierarchy [T]ree',
    }
  )
end

return T
