-- Multi-module Gradle build with Lombok and JUnit 5 (fixtures/gradle-java). One child for the whole file.
local helpers = require 'tests.helpers'
local e2e = require 'tests.e2e.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()
local project

local T = MiniTest.new_set {
  hooks = {
    pre_once = function()
      project = e2e.copy_fixture 'gradle-java'
      child.start()
      child.cmd('cd ' .. project)
      e2e.record_jdtls_status(child)
    end,
    post_once = function() child.stop() end,
  },
}

local main = 'app/src/main/java/com/example/app/Main.java'

T['gradle-java | LSP | jdtls attaches, resolves Lombok getters, reports no errors'] = function()
  child.cmd('edit ' .. main)
  e2e.wait(child, 'attach', 'jdtls attached', "#vim.lsp.get_clients { bufnr = 0, name = 'jdtls' } > 0")
  eq(child.lua_get "vim.lsp.get_clients({ bufnr = 0, name = 'jdtls' })[1].root_dir", project)
  e2e.wait(child, 'index', 'jdtls ServiceReady', "_G.e2e.jdtls_status == 'ServiceReady'")

  -- Definition of the Lombok-generated getName() leads to Person.java; without Lombok it resolves nowhere.
  e2e.wait(
    child,
    'index',
    'definition of person.getName() in Person.java',
    [[(function()
      local line = vim.fn.search('getName', 'n')
      local col = vim.fn.getline(line):find('getName', 1, true) - 1
      local params = { textDocument = vim.lsp.util.make_text_document_params(0), position = { line = line - 1, character = col } }
      local res = vim.lsp.buf_request_sync(0, 'textDocument/definition', params, 5000) or {}
      for _, r in pairs(res) do
        for _, loc in ipairs(vim.islist(r.result or {}) and r.result or { r.result }) do
          if (loc.uri or loc.targetUri or ''):find('Person.java', 1, true) then return true end
        end
      end
    end)()]]
  )

  -- The unused import's warning proves diagnostics for this file are in; then nothing may be an error.
  e2e.wait(child, 'index', 'unused import warning in Main.java', '#vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN }) > 0')
  eq(child.lua_get 'vim.tbl_map(function(d) return d.message end, vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR }))', {})
end

return T
