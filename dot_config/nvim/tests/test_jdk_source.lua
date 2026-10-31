local jdk_source = require 'custom.jvm.jdk_source'
local entry = jdk_source.entry
local jar_entry = jdk_source.jar_entry
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['entry()'] = MiniTest.new_set()

-- kotlin_lsp answers go-to-definition on a JDK class with a jrt: URI into its own bundled JDK.
local jrt = 'jrt:///private/tmp/kotlin-server/jbr/Contents/Home!/java.base/java/util/ArrayList.class'

T['entry()']['maps a jrt: class URI to its source file in src.zip'] = function() eq(entry(jrt), 'java.base/java/util/ArrayList.java') end

T['entry()']['maps a nested class to its outer class source'] = function()
  eq(entry 'jrt:///jbr/Home!/java.base/java/util/Map$Entry.class', 'java.base/java/util/Map.java')
end

T['entry()']['maps an anonymous class to its outer class source'] = function()
  eq(entry 'jrt:///jbr/Home!/java.base/java/util/HashMap$1.class', 'java.base/java/util/HashMap.java')
end

T['entry()']['is nil for anything but a jrt: class URI'] = function()
  eq(entry 'file:///src/Main.java', nil)
  eq(entry 'jdt://contents/java.base/java.util/List.java', nil)
  eq(entry 'jrt:///jbr/Home!/java.base/java/util/ArrayList.txt', nil)
end

T['jar_entry()'] = MiniTest.new_set()

-- kotlin_lsp answers with jar: URIs: JDK sources in the project JDK's src.zip, library sources in sources jars.
local jdk_src = 'jar:file:///Users/me/.local/share/mise/installs/java/21/lib/src.zip!/java.base/java/time/Duration.java'
local lib_src = 'jar:file:///Users/me/.gradle/caches/kotlin-stdlib-2.4.20-sources.jar!/jvmMain/kotlin/String.kt'

T['jar_entry()']['splits a jar: URI into its zip file and entry'] = function()
  eq({ jar_entry(jdk_src) }, { '/Users/me/.local/share/mise/installs/java/21/lib/src.zip', 'java.base/java/time/Duration.java' })
end

T['jar_entry()']['handles sources jars of libraries'] = function()
  eq({ jar_entry(lib_src) }, { '/Users/me/.gradle/caches/kotlin-stdlib-2.4.20-sources.jar', 'jvmMain/kotlin/String.kt' })
end

T['jar_entry()']['handles the jar:///path form kotlin_lsp sends'] = function()
  eq({ jar_entry 'jar:///Users/me/.local/share/mise/installs/java/21/lib/src.zip!/java.base/java/time/Duration.java' }, {
    '/Users/me/.local/share/mise/installs/java/21/lib/src.zip',
    'java.base/java/time/Duration.java',
  })
end

T['jar_entry()']['decodes percent-encoded paths'] = function()
  eq({ jar_entry 'jar:file:///Users/me/My%20Libs/a.jar!/x/Y.kt' }, { '/Users/me/My Libs/a.jar', 'x/Y.kt' })
end

T['jar_entry()']['is nil for anything but a jar: URI'] = function()
  eq({ jar_entry 'file:///src/Main.kt' }, {})
  eq({ jar_entry 'jrt:///jbr/Home!/java.base/java/util/ArrayList.class' }, {})
end

return T
