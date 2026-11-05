local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()
local T = MiniTest.new_set { hooks = { pre_case = child.start, post_once = child.stop } }

local server = vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'fake_lsp_missing_result.lua')

T['a response with neither result nor error reaches its request as a null result, without an error message'] = function()
  child.lua(
    [[
    local server = ...
    vim.lsp.start {
      name = 'fake',
      cmd = { vim.v.progpath, '-l', server },
      root_dir = vim.fn.getcwd(),
      on_init = require('custom.lsp_missing_result').patch,
    }
    vim.wait(5000, function() return #vim.lsp.get_clients { bufnr = 0 } > 0 end)
    vim.cmd 'messages clear'
    _G.answered = nil
    local params = vim.lsp.util.make_position_params(0, 'utf-16')
    vim.lsp.buf_request_all(0, 'textDocument/typeDefinition', params, function(responses) _G.answered = responses end)
    vim.wait(5000, function() return _G.answered ~= nil end)
  ]],
    { server }
  )
  eq(child.lua_get "_G.answered and vim.tbl_map(function(r) return { err = r.err, result = r.result } end, vim.tbl_values(_G.answered)) or 'no answer'", { {} })
  eq(child.lua_get "vim.api.nvim_exec2('messages', { output = true }).output", '')
  eq(child.lua_get 'vim.tbl_count(vim.lsp.get_clients()[1].requests)', 0)
end

return T
