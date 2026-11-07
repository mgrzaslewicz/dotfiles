-- LSP-behavior features on fixtures/maven-mixed, answered by the contracts of jdtls (Java files) and kotlin-lsp
-- (Kotlin files) (tests/replay.lua). `tests/run.sh --smoke` runs the same cases against the real servers, `--record`
-- records the contracts.
local replay = require 'tests.replay'
local eq = MiniTest.expect.equality

local T, ctx = replay.session('maven-mixed', {
  jdtls = { file = 'core/src/main/java/com/example/mixed/Report.java', symbol = 'greet', target = 'core/src/main/java/com/example/mixed/JavaGreeter.java' },
  kotlin_lsp = { file = 'app/src/main/kotlin/com/example/app/Main.kt', symbol = 'greet', target = 'core/src/main/java/com/example/mixed/JavaGreeter.java' },
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

T['maven-mixed | gry | in a Java file, the method around the cursor'] = function()
  eq(reference('core/src/main/java/com/example/mixed/JavaGreeter.java', 'return "Hello'), 'com.example.mixed.JavaGreeter#greet')
end

T['maven-mixed | gry | in a Kotlin file, the member of a class'] = function()
  eq(reference('core/src/main/kotlin/com/example/mixed/KotlinFormatter.kt', 'uppercase'), 'com.example.mixed.KotlinFormatter#shout')
end

return T
