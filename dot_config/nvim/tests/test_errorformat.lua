local efm = require 'custom.jvm.errorformat'
local eq = MiniTest.expect.equality

-- Parses without touching any quickfix list. Type letters keep the case of the tool's output (`e` from
-- "error:", `E` from "[ERROR]"); quickfix treats both the same, so they are compared upper-cased.
local function parse(line)
  local items = vim.tbl_filter(function(item) return item.valid == 1 end, vim.fn.getqflist({ lines = { line }, efm = efm }).items)
  return vim.tbl_map(
    function(item) return { file = vim.fn.bufname(item.bufnr), lnum = item.lnum, col = item.col, type = item.type:upper(), text = item.text } end,
    items
  )
end

local T = MiniTest.new_set()

T['javac error'] = function()
  eq(parse '/src/Foo.java:12: error: cannot find symbol', { { file = '/src/Foo.java', lnum = 12, col = 0, type = 'E', text = 'cannot find symbol' } })
end

T['javac warning'] = function()
  eq(parse '/src/Foo.java:7: warning: [deprecation] old() in Bar has been deprecated', {
    { file = '/src/Foo.java', lnum = 7, col = 0, type = 'W', text = '[deprecation] old() in Bar has been deprecated' },
  })
end

T['kotlinc error with file:// URI (Kotlin 1.8+)'] = function()
  eq(parse "e: file:///src/Foo.kt:12:5 Unresolved reference 'x'.", {
    { file = '/src/Foo.kt', lnum = 12, col = 5, type = 'E', text = "Unresolved reference 'x'." },
  })
end

T['kotlinc warning with file:// URI'] = function()
  eq(parse "w: file:///src/Foo.kt:3:9 Variable 'y' is never used", {
    { file = '/src/Foo.kt', lnum = 3, col = 9, type = 'W', text = "Variable 'y' is never used" },
  })
end

T['kotlinc error, old format'] = function()
  eq(parse 'e: /src/Foo.kt: (12, 5): Unresolved reference: x', {
    { file = '/src/Foo.kt', lnum = 12, col = 5, type = 'E', text = 'Unresolved reference: x' },
  })
end

T['Maven error'] = function()
  eq(parse '[ERROR] /src/Foo.java:[12,5] cannot find symbol', { { file = '/src/Foo.java', lnum = 12, col = 5, type = 'E', text = 'cannot find symbol' } })
end

T['Maven warning'] = function()
  eq(parse '[WARNING] /src/Foo.java:[7,3] unchecked conversion', { { file = '/src/Foo.java', lnum = 7, col = 3, type = 'W', text = 'unchecked conversion' } })
end

T['kotlin-maven-plugin error with file:// URI'] = function()
  eq(parse "[ERROR] file:///src/Foo.kt:12:5 Unresolved reference 'x'.", {
    { file = '/src/Foo.kt', lnum = 12, col = 5, type = 'E', text = "Unresolved reference 'x'." },
  })
end

T['build progress output is not an entry'] = function()
  eq(parse '> Task :app:compileKotlin FAILED', {})
  eq(parse '[INFO] BUILD FAILURE', {})
  eq(parse 'BUILD SUCCESSFUL in 3s', {})
end

return T
