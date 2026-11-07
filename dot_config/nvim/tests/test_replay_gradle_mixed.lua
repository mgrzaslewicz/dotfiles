-- LSP-behavior features on fixtures/gradle-mixed, answered by the contracts of jdtls (Java files) and kotlin-lsp
-- (Kotlin files) (tests/replay.lua). `tests/run.sh --smoke` runs the same cases against the real servers, `--record`
-- records the contracts.
local replay = require 'tests.replay'
local eq = MiniTest.expect.equality

local T, ctx = replay.session('gradle-mixed', {
  jdtls = { file = 'src/main/java/com/example/mixed/Report.java', symbol = 'greet', target = 'src/main/java/com/example/mixed/JavaGreeter.java' },
  kotlin_lsp = { file = 'src/main/kotlin/com/example/mixed/Main.kt', symbol = 'greet', target = 'src/main/java/com/example/mixed/JavaGreeter.java' },
})
local child = ctx.child

--- Copies the reference of the declaration around the first `text` in `file` and returns it.
local function reference(file, text)
  ctx.edit(file)
  ctx.cursor(text)
  child.lua "vim.fn.setreg('+', '') require('custom.copy_reference').copy()"
  ctx.wait('a reference copied', "vim.fn.getreg('+') ~= ''")
  return child.lua_get "vim.fn.getreg('+')"
end

T['gradle-mixed | gry | in a Java file, the method around the cursor'] = function()
  eq(reference('src/main/java/com/example/mixed/Report.java', 'return new'), 'com.example.mixed.Report#headline')
end

T['gradle-mixed | gry | in a Kotlin file, the top-level function around the cursor'] = function()
  eq(reference('src/main/kotlin/com/example/mixed/Main.kt', 'println'), 'com.example.mixed.main')
end

return T
