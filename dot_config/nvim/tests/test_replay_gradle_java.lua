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

T['gradle-java | <M-m>c | in the body of an override lists its callers and those of the interface method'] = function()
  ctx.capture_pick()
  ctx.edit(FORMAL)
  ctx.cursor('return "Good day', 0)
  child.lua "require('custom.implementations').method_incoming_calls()"
  ctx.wait('incoming calls picked', '_G.picked ~= nil')
  -- jdtls answers both calls as calls of Formal.greet (and of Greeting.greet): all are its own, in file order.
  eq(child.lua_get '_G.picked', { 'Incoming calls of greet, with its supers and implementations', { CALLERS .. ':9', CALLERS .. ':13' } })
end

-- `formal.greet(...)` calls Formal.greet, which the interface method's incoming calls leave out.
T['gradle-java | <M-m>c | on the interface method lists the callers of its implementation too'] = function()
  ctx.capture_pick()
  ctx.edit(GREETING)
  ctx.cursor('String greet', 0)
  child.lua "require('custom.implementations').method_incoming_calls()"
  ctx.wait('incoming calls picked', '_G.picked ~= nil')
  eq(child.lua_get '_G.picked', { 'Incoming calls of greet, with its supers and implementations', { CALLERS .. ':9', CALLERS .. ':13' } })
end

T['gradle-java | <M-m>C | in a method body lists the method it calls, at its declaration'] = function()
  ctx.capture_pick()
  ctx.edit(CALLERS)
  ctx.cursor('return formal', 0)
  child.lua "require('custom.implementations').method_outgoing_calls()"
  ctx.wait('outgoing calls picked', '_G.picked ~= nil')
  eq(child.lua_get '_G.picked', { 'Outgoing calls of throughClass', { FORMAL .. ':7' } })
end

T['gradle-java | <M-m>i | in the interface method lists its implementation, like gri'] = function()
  ctx.capture_pick()
  ctx.edit(GREETING)
  ctx.cursor('String greet', 0)
  child.lua "require('custom.implementations').method_implementations()"
  ctx.wait('implementations picked', '_G.picked ~= nil')
  eq(child.lua_get '_G.picked', { 'Implementations of greet', { FORMAL .. ':7' } })
end

T['gradle-java | <M-m>i | in the body of an override lists the implementations of the interface method, like gri'] = function()
  ctx.capture_pick()
  ctx.edit(FORMAL)
  ctx.cursor('return "Good day', 0)
  child.lua "require('custom.implementations').method_implementations()"
  ctx.wait('implementations picked', '_G.picked ~= nil')
  eq(child.lua_get '_G.picked', { 'Implementations of greet', { FORMAL .. ':7' } })
end

T['gradle-java | <M-m>H | in the body of an override lists the interface method'] = function()
  ctx.capture_pick()
  ctx.edit(FORMAL)
  ctx.cursor('return "Good day', 0)
  child.lua "require('custom.implementations').method_supers()"
  ctx.wait('supers picked', '_G.picked ~= nil')
  eq(child.lua_get '_G.picked', { 'Supers of greet', { GREETING .. ':6' } })
end

T['gradle-java | <M-m>h | in the interface method lists its override'] = function()
  ctx.capture_pick()
  ctx.edit(GREETING)
  ctx.cursor('String greet', 0)
  child.lua "require('custom.implementations').method_overrides()"
  ctx.wait('overrides picked', '_G.picked ~= nil')
  eq(child.lua_get '_G.picked', { 'Overrides of greet', { FORMAL .. ':7' } })
end

T['gradle-java | <M-m>s | in the body of an override goes to the interface method'] = function()
  ctx.edit(FORMAL)
  ctx.cursor('return "Good day', 0)
  child.lua "require('custom.implementations').goto_super()"
  ctx.wait('Greeting.java opened', "vim.endswith(vim.api.nvim_buf_get_name(0), 'Greeting.java')")
  eq(ctx.position()[2], 6)
end

T['gradle-java | <M-m>r | in the body of an override lists the usages of it and of the interface method'] = function()
  ctx.capture_pick()
  ctx.edit(FORMAL)
  ctx.cursor('return "Good day', 0)
  child.lua "require('custom.implementations').method_usages()"
  ctx.wait('usages picked', '_G.picked ~= nil')
  local picked = child.lua_get '_G.picked'
  eq(picked[1], 'Usages of greet, with its supers and implementations')
  eq({ vim.tbl_contains(picked[2], CALLERS .. ':9'), vim.tbl_contains(picked[2], CALLERS .. ':13') }, { true, true })
  eq(vim.tbl_contains(picked[2], FORMAL .. ':7'), false)
end

T['gradle-java | <M-m>t | in a method body lists the test methods calling it'] = function()
  ctx.capture_pick()
  ctx.edit 'app/src/main/java/com/example/app/Main.java'
  ctx.cursor('return "Hello', 0)
  child.lua "require('custom.method_tests').goto_tests()"
  ctx.wait('tests picked', '_G.picked ~= nil')
  local test = 'app/src/test/java/com/example/app/MainTest.java'
  eq(child.lua_get '_G.picked', { 'Tests of greeting', { test .. ':9', test .. ':14' } })
end

T['gradle-java | <M-m>v | in a method body selects the method with its annotation'] = function()
  ctx.edit(FORMAL)
  ctx.cursor('return "Good day', 0)
  child.lua "require('custom.implementations').select_method()"
  ctx.wait('method selected', "vim.fn.mode() == 'V'")
  eq({ child.lua_get "vim.fn.line('v')", child.lua_get "vim.fn.line('.')" }, { 6, 9 })
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
