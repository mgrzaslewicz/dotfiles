local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality
local implementations = require 'custom.implementations'

local function range(line, character) return { start = { line = line, character = character }, ['end'] = { line = line, character = character + 3 } } end

local function loc(uri, line, character) return { uri = uri, range = range(line, character) } end

local T = MiniTest.new_set()

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
      local file = helpers.tree { ['Foo.kt'] = string.rep('\n', 2) .. 'fun run() {}' .. string.rep('\n', 12) }
      child.cmd('edit ' .. file .. '/Foo.kt')
      child.lua [=[
        -- Fake server: `run` on line 3 is implemented on line 10. References of the interface method are on
        -- line 6, of the implementation on line 13; implementations answer as LocationLink.
        local uri = vim.uri_from_bufnr(0)
        local function at(l, c) return { uri = uri, range = { start = { line = l, character = c }, ['end'] = { line = l, character = c + 3 } } } end
        _G.fake = {
          implementation = function() return { { originSelectionRange = at(2, 4).range, targetUri = uri, targetRange = at(9, 0).range, targetSelectionRange = at(9, 4).range } } end,
          definition = function() return { { uri = uri, range = at(9, 4).range } } end,
        }
        vim.lsp.start {
          name = 'impls',
          root_dir = vim.fn.getcwd(),
          cmd = function()
            local closing = false
            return {
              request = function(method, params, callback)
                local handlers = {
                  initialize = function() return { capabilities = { implementationProvider = true, referencesProvider = true, definitionProvider = true } } end,
                  ['textDocument/implementation'] = function() return _G.fake.implementation() end,
                  ['textDocument/definition'] = function() return _G.fake.definition() end,
                  ['textDocument/references'] = function() return params.position.line == 2 and { at(5, 4) } or { at(12, 8) } end,
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

T['collect()']['grR is mapped in LSP buffers next to grr, and grr keeps its own mapping'] = function()
  child.lua [=[ _G.grR = vim.fn.maparg('grR', 'n', false, true) ]=]
  eq(child.lua_get '_G.grR.buffer', 1)
  eq(child.lua_get '_G.grR.desc', '[G]oto [R]eferences incl. implementations')
  eq(child.lua_get "vim.fn.maparg('grr', 'n', false, true).desc", '[G]oto [R]eferences')
end

return T
