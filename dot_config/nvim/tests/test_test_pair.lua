-- `<leader>ut`: the test file of an implementation file and back, by the Gradle/Maven layout (src/main ↔ src/test,
-- `Foo.kt` ↔ `FooTest.kt`). Pure path mapping in custom.jvm.test_pair; the keymap is checked in a child nvim.
local helpers = require 'tests.helpers'
local counterpart = require('custom.jvm.test_pair').counterpart
local eq = MiniTest.expect.equality

local child = helpers.new_child()
local T = MiniTest.new_set { hooks = { post_case = function() child.stop() end } }

T['counterpart()'] = MiniTest.new_set()

T['counterpart()']['maps an implementation file to its test file'] = function()
  eq(counterpart '/p/app/src/main/kotlin/com/example/app/Main.kt', '/p/app/src/test/kotlin/com/example/app/MainTest.kt')
  eq(counterpart '/p/app/src/main/java/com/example/app/Main.java', '/p/app/src/test/java/com/example/app/MainTest.java')
end

T['counterpart()']['maps a test file back to its implementation file'] = function()
  eq(counterpart '/p/app/src/test/kotlin/com/example/app/MainTest.kt', '/p/app/src/main/kotlin/com/example/app/Main.kt')
  eq(counterpart '/p/app/src/test/java/com/example/app/MainTest.java', '/p/app/src/main/java/com/example/app/Main.java')
end

T['counterpart()']['keeps the module directory of a multi-module build'] = function()
  eq(counterpart '/p/core/src/main/java/com/example/mixed/JavaGreeter.java', '/p/core/src/test/java/com/example/mixed/JavaGreeterTest.java')
end

T['counterpart()']['is nil outside src/main and src/test, and for other languages'] = function()
  eq(counterpart '/p/app/build.gradle.kts', nil)
  eq(counterpart '/p/app/src/main/resources/app.yml', nil)
  eq(counterpart '/p/app/src/main/rust/main.rs', nil)
  eq(counterpart 'Main.kt', nil)
end

T['<leader>ut'] = function()
  local root = helpers.tree {
    ['settings.gradle.kts'] = '',
    ['app/build.gradle.kts'] = '',
    ['app/src/main/kotlin/com/example/app/Main.kt'] = 'package com.example.app\n',
    ['app/src/test/kotlin/com/example/app/MainTest.kt'] = 'package com.example.app\n',
  }
  child.start()
  child.cmd('edit ' .. root .. '/app/src/main/kotlin/com/example/app/Main.kt')
  child.type_keys(' ', 'u', 't')
  eq(child.lua_get 'vim.api.nvim_buf_get_name(0)', root .. '/app/src/test/kotlin/com/example/app/MainTest.kt')

  child.type_keys(' ', 'u', 't')
  eq(child.lua_get 'vim.api.nvim_buf_get_name(0)', root .. '/app/src/main/kotlin/com/example/app/Main.kt')
end

return T
