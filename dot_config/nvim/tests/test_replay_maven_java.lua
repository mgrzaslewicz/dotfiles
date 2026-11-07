-- LSP-behavior features on fixtures/maven-java, answered by jdtls's contract (tests/replay.lua). `tests/run.sh --smoke`
-- runs the same cases against a real jdtls, `--record` records the contract.
local replay = require 'tests.replay'
local eq = MiniTest.expect.equality

local T, ctx = replay.session('maven-java', {
  jdtls = { file = 'app/src/main/java/com/example/app/Main.java', symbol = 'getName', target = 'model/src/main/java/com/example/model/Person.java' },
})
local child = ctx.child

-- `println` has no result type: jdtls answers its typeDefinition with nothing, which once left `grM` without an answer
-- and an error message (custom/lsp_missing_result.lua).
T['maven-java | grM | answers on a method calling one without a result type, without an error message'] = function()
  ctx.edit 'app/src/main/java/com/example/app/Main.java'
  child.cmd 'messages clear'
  ctx.cursor 'println'
  child.lua [[
    _G.types = nil
    require('custom.method_types').collect(function(types)
      _G.types = vim.tbl_map(function(t) return vim.fs.basename(vim.uri_to_fname(t.uri)) end, types or {})
    end)
  ]]
  ctx.wait('method types collected', '_G.types ~= nil')
  eq(vim.tbl_contains(child.lua_get '_G.types', 'Person.java'), true)
  eq(child.lua_get "vim.api.nvim_exec2('messages', { output = true }).output", '')
end

return T
