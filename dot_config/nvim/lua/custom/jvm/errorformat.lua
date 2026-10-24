-- 'errorformat' for javac, kotlinc and Maven output, used by the Gradle/Maven tasks (custom/plugins/tasks.lua)
-- to fill the quickfix list. Tests: tests/test_errorformat.lua.
-- kotlinc's message format has changed between Kotlin Gradle Plugin versions; a new one gets a test case here.
--
-- javac:   /path/Foo.java:12: error: cannot find symbol
-- kotlinc: e: file:///path/Foo.kt:12:5 Unresolved reference 'x'   (Kotlin 1.8+; older: e: /path/Foo.kt: (12, 5): …)
-- Maven:   [ERROR] /path/Foo.java:[12,5] cannot find symbol         (kotlin-maven-plugin: [ERROR] file:///path/Foo.kt:12:5 …)
return table.concat({
  '%f:%l: %trror: %m',
  '%f:%l: %tarning: %m',
  '%t: file://%f:%l:%c %m',
  '%t: %f: (%l\\, %c): %m',
  '[%tRROR] file://%f:%l:%c %m',
  '[%tARNING] file://%f:%l:%c %m',
  '[%tRROR] %f:[%l\\,%c] %m',
  '[%tARNING] %f:[%l\\,%c] %m',
}, ',')
