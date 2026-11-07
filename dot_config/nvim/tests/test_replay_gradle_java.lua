-- LSP-behavior features on fixtures/gradle-java, answered by jdtls's contract (tests/replay.lua). `tests/run.sh
-- --smoke` runs the same cases against a real jdtls, `--record` records the contract.
local replay = require 'tests.replay'
local eq = MiniTest.expect.equality

local T, ctx = replay.session('gradle-java', {
  jdtls = { file = 'app/src/main/java/com/example/app/Main.java', symbol = 'getName', target = 'model/src/main/java/com/example/model/Person.java' },
})
local child = ctx.child

local MAIN = 'app/src/main/java/com/example/app/Main.java'
local GREETING = 'model/src/main/java/com/example/model/Greeting.java'
local FORMAL = 'model/src/main/java/com/example/model/Formal.java'
local CALLERS = 'app/src/main/java/com/example/app/Callers.java'

T['gradle-java | gry | copies the reference of the method around the cursor'] = function()
  ctx.edit(MAIN)
  ctx.cursor 'return "Hello, "'
  child.lua "require('custom.copy_reference').copy()"
  ctx.wait('a reference copied', "vim.fn.getreg('+') ~= ''")
  eq(child.lua_get "vim.fn.getreg('+')", 'com.example.app.Main#greeting')
end

T['gradle-java | ]r | goes to the next usage of a local variable'] = function()
  ctx.edit(MAIN)
  ctx.cursor('Person person', 7)
  child.lua "require('custom.usages').jump(1)"
  ctx.wait('the cursor moved', 'vim.api.nvim_win_get_cursor(0)[1] ~= 8')
  eq(ctx.position(), { MAIN, 9, 36 })
end

-- The override cases below cover jdtls's method names, which carry the signature (`greet(String)`) where kotlin-lsp's
-- are bare.
T['gradle-java | grs | from an override goes to the interface method'] = function()
  ctx.edit(FORMAL)
  ctx.cursor('String greet', 7)
  child.lua "require('custom.implementations').goto_super()"
  ctx.wait('Greeting.java opened', "vim.endswith(vim.api.nvim_buf_get_name(0), 'Greeting.java')")
  eq(ctx.position(), { GREETING, 6, 11 })
end

T['gradle-java | grs | from the body of an override goes to the interface method'] = function()
  ctx.edit(FORMAL)
  ctx.cursor 'return "Good day, "'
  child.lua "require('custom.implementations').goto_super()"
  ctx.wait('Greeting.java opened', "vim.endswith(vim.api.nvim_buf_get_name(0), 'Greeting.java')")
  eq(ctx.position(), { GREETING, 6, 11 })
end

T['gradle-java | grs | on a method that overrides nothing says so'] = function()
  ctx.edit(MAIN)
  child.cmd 'messages clear'
  ctx.cursor('String greeting', 7)
  child.lua "require('custom.implementations').goto_super()"
  ctx.wait('a message', "vim.api.nvim_exec2('messages', { output = true }).output ~= ''")
  eq(child.lua_get "vim.api.nvim_exec2('messages', { output = true }).output", 'greeting overrides no method')
  eq(ctx.position(), { MAIN, 12, 18 })
end

T['gradle-java | grd | on an override goes to the interface method'] = function()
  ctx.edit(FORMAL)
  ctx.cursor('String greet', 7)
  child.lua "require('custom.implementations').goto_definition()"
  ctx.wait('Greeting.java opened', "vim.endswith(vim.api.nvim_buf_get_name(0), 'Greeting.java')")
  eq(ctx.position(), { GREETING, 6, 11 })
end

T['gradle-java | gri | on an override lists the implementations of the interface method'] = function()
  ctx.capture_pick()
  ctx.edit(FORMAL)
  ctx.cursor('String greet', 7)
  child.lua "require('custom.implementations').goto_implementation()"
  ctx.wait('implementations picked', '_G.picked ~= nil')
  eq(child.lua_get '_G.picked', { 'Implementations of greet', { FORMAL .. ':7' } })
end

T['gradle-java | grc | on an override lists its callers and those of the interface method'] = function()
  ctx.capture_pick()
  ctx.edit(FORMAL)
  ctx.cursor('String greet', 7)
  child.lua "require('custom.implementations').incoming_calls()"
  ctx.wait('incoming calls picked', '_G.picked ~= nil')
  eq(child.lua_get '_G.picked', { 'Incoming calls of greet, with the overridden method', { CALLERS .. ':9', CALLERS .. ':13' } })
end

T['gradle-java | gri | on the interface method lists its implementation'] = function()
  ctx.capture_pick()
  ctx.edit(GREETING)
  ctx.cursor('greet(', 0)
  child.lua "require('custom.implementations').goto_implementation()"
  ctx.wait('implementations picked', '_G.picked ~= nil')
  eq(child.lua_get '_G.picked', { 'Implementations of greet', { FORMAL .. ':7' } })
end

T['gradle-java | grR | references of the interface method include its implementation'] = function()
  ctx.edit(GREETING)
  ctx.cursor('greet(', 0)
  child.lua [[
    _G.references = nil
    require('custom.implementations').collect(function(locations)
      _G.references = vim.tbl_map(_G.replay.location, locations)
    end)
  ]]
  ctx.wait('references collected', '_G.references ~= nil')
  eq(child.lua_get '_G.references', { CALLERS .. ':9', CALLERS .. ':13', FORMAL .. ':7', GREETING .. ':6' })
end

T['gradle-java | gW | lists the workspace symbols matching the query'] = function()
  ctx.edit(MAIN)
  child.lua [[
    _G.symbols = nil
    require('custom.workspace_symbols').symbols(0, 'Greeting', function(items)
      _G.symbols = vim.tbl_map(function(i) return i.text .. ' ' .. vim.fs.relpath(vim.fn.getcwd(), i.filename) end, vim.tbl_filter(function(i) return vim.fs.relpath(vim.fn.getcwd(), i.filename) ~= nil end, items))
    end)
  ]]
  ctx.wait('workspace symbols listed', '_G.symbols ~= nil')
  eq(child.lua_get '_G.symbols', { '[Interface] Greeting in com.example.model ' .. GREETING })
end

return T
