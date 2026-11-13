-- LSP-behavior features on fixtures/gradle-kotlin, answered by kotlin-lsp's contract (tests/replay.lua). `tests/run.sh
-- --smoke` runs the same cases against a real kotlin-lsp, `--record` records the contract.
local replay = require 'tests.replay'
local eq = MiniTest.expect.equality

local T, ctx = replay.session('gradle-kotlin', {
  kotlin_lsp = { file = 'app/src/main/kotlin/com/example/app/Main.kt', symbol = 'greet', target = 'lib/src/main/kotlin/com/example/lib/Greeter.kt', jdk = true },
})
local child = ctx.child

local MAIN = 'app/src/main/kotlin/com/example/app/Main.kt'
local GREETING = 'lib/src/main/kotlin/com/example/lib/Greeting.kt'
local FORMAL = 'lib/src/main/kotlin/com/example/lib/Formal.kt'

-- kotlin_lsp answers a JDK class with a URI into a JDK (`jrt:`, or `jar:` into a src.zip); the buffer reads its source.
-- `grd` outside an override shows the answer through Telescope's definitions picker, which does not use the request
-- seam, so the case asks for the definition through the seam and opens it the way the picker does.
T['gradle-kotlin | JDK source | go to definition of a JDK class opens a read-only Java buffer for it'] = function()
  ctx.edit(MAIN)
  child.lua [=[
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'val probe = java.util.ArrayList<String>()' })
    local pos = vim.fn.searchpos('\\<ArrayList\\>', 'nw')
    local params = { textDocument = vim.lsp.util.make_text_document_params(0), position = { line = pos[1] - 1, character = pos[2] - 1 } }
    _G.jdk = nil
    require('custom.implementations').request_all('textDocument/definition', params, function(locations)
      local loc = locations[1]
      if loc then vim.lsp.util.show_document(loc, 'utf-16', { reuse_win = true }) end
      _G.jdk = { name = vim.api.nvim_buf_get_name(0), filetype = vim.bo.filetype, modifiable = vim.bo.modifiable }
    end)
  ]=]
  ctx.wait('definition of ArrayList answered', '_G.jdk ~= nil')
  local jdk = child.lua_get '_G.jdk'
  local jdk_uri = vim.startswith(jdk.name, 'jrt:') or vim.startswith(jdk.name, 'jar:')
  eq({ jdk_uri, jdk.name:match 'java/util/ArrayList%.%a+$' ~= nil, jdk.filetype, jdk.modifiable }, { true, true, 'java', false })
end

T['gradle-kotlin | gry | copies the reference of a top-level function'] = function()
  ctx.edit(MAIN)
  ctx.cursor 'Greeter("Hello")'
  child.lua "require('custom.copy_reference').copy()"
  ctx.wait('a reference copied', "vim.fn.getreg('+') ~= ''")
  eq(child.lua_get "vim.fn.getreg('+')", 'com.example.app.greeting')
end

T['gradle-kotlin | grs | from an override goes to the interface method'] = function()
  ctx.edit(FORMAL)
  ctx.cursor('fun greet', 4)
  child.lua "require('custom.implementations').goto_super()"
  ctx.wait('Greeting.kt opened', "vim.endswith(vim.api.nvim_buf_get_name(0), 'Greeting.kt')")
  eq(ctx.position(), { GREETING, 4, 8 })
end

T['gradle-kotlin | grd | on an override goes to the interface method'] = function()
  ctx.edit(FORMAL)
  ctx.cursor('fun greet', 4)
  child.lua "require('custom.implementations').goto_definition()"
  ctx.wait('Greeting.kt opened', "vim.endswith(vim.api.nvim_buf_get_name(0), 'Greeting.kt')")
  eq(ctx.position(), { GREETING, 4, 8 })
end

T['gradle-kotlin | gri | on the interface method lists its implementation'] = function()
  ctx.capture_pick()
  ctx.edit(GREETING)
  ctx.cursor('fun greet', 4)
  child.lua "require('custom.implementations').goto_implementation()"
  ctx.wait('implementations picked', '_G.picked ~= nil')
  eq(child.lua_get '_G.picked', { 'Implementations of greet', { FORMAL .. ':5' } })
end

T['gradle-kotlin | grM | lists the types of a function: its return type and the classes its body uses'] = function()
  ctx.edit(MAIN)
  ctx.cursor('fun greeting', 4)
  child.lua [[
    _G.types = nil
    require('custom.method_types').collect(function(types)
      _G.types = vim.tbl_map(function(t) return t.group .. ' ' .. t.name end, types or {})
    end)
  ]]
  ctx.wait('method types collected', '_G.types ~= nil')
  local types = child.lua_get '_G.types'
  eq({ vim.tbl_contains(types, 'returns String'), vim.tbl_contains(types, 'body Greeter') }, { true, true })
end

return T
