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

T['class_path()'] = MiniTest.new_set()

T['class_path()']['uses the explicit import of the word'] = function()
  eq(jdk_source.class_path('Objects', { 'package java.time', 'import java.util.Objects;' }), 'java/util/Objects.java')
end

T['class_path()']['uses the package when the word is not imported'] = function()
  eq(jdk_source.class_path('Instant', { 'package java.time', 'import java.util.Objects;' }), 'java/time/Instant.java')
end

T['class_path()']['falls back to java.lang'] = function()
  eq(jdk_source.class_path('String', { 'package java.util' }), 'java/util/String.java')
  eq(jdk_source.class_path('String', {}), 'java/lang/String.java')
end

T['class_path()']['accepts a Kotlin import without semicolon'] = function()
  eq(jdk_source.class_path('UUID', { 'import java.util.UUID' }), 'java/util/UUID.java')
end

T['class_path()']['is nil for a non-identifier'] = function()
  eq(jdk_source.class_path('a.b', {}), nil)
  eq(jdk_source.class_path('', {}), nil)
end

T['find_entry()'] = MiniTest.new_set()

T['find_entry()']['matches the entry under its module directory'] = function()
  eq(
    jdk_source.find_entry({ 'java.base/java/util/Objects.java', 'java.base/java/util/ObjectsX.java' }, 'java/util/Objects.java'),
    'java.base/java/util/Objects.java'
  )
end

T['find_entry()']['does not match a longer path with the same tail'] = function()
  eq(jdk_source.find_entry({ 'java.base/xjava/util/Objects.java' }, 'java/util/Objects.java'), nil)
end

T['sources_jar()'] = MiniTest.new_set()

T['sources_jar()']['finds the sources jar next to a Maven jar'] = function()
  local dir = vim.fn.tempname() .. '/g/a/1.0'
  vim.fn.mkdir(dir, 'p')
  vim.fn.writefile({}, dir .. '/a-1.0.jar')
  vim.fn.writefile({}, dir .. '/a-1.0-sources.jar')
  eq(jdk_source.sources_jar(dir .. '/a-1.0.jar'), dir .. '/a-1.0-sources.jar')
end

T['sources_jar()']['finds the sources jar in a sibling Gradle hash directory'] = function()
  local version = vim.fn.tempname() .. '/g/a/1.0'
  vim.fn.mkdir(version .. '/aaa', 'p')
  vim.fn.mkdir(version .. '/bbb', 'p')
  vim.fn.writefile({}, version .. '/aaa/a-1.0.jar')
  vim.fn.writefile({}, version .. '/bbb/a-1.0-sources.jar')
  eq(jdk_source.sources_jar(version .. '/aaa/a-1.0.jar'), version .. '/bbb/a-1.0-sources.jar')
end

T['sources_jar()']['is nil when no sources jar exists'] = function()
  local version = vim.fn.tempname() .. '/g/a/1.0'
  vim.fn.mkdir(version .. '/aaa', 'p')
  vim.fn.writefile({}, version .. '/aaa/a-1.0.jar')
  eq(jdk_source.sources_jar(version .. '/aaa/a-1.0.jar'), nil)
end

T['class_source()'] = MiniTest.new_set()

-- A sources jar holding `org/x/Y.kt`, zipped from a temp directory; `jar` is the binary jar beside it.
local function sources_fixture()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir .. '/src/org/x', 'p')
  vim.fn.writefile({ 'class Y' }, dir .. '/src/org/x/Y.kt')
  vim.system({ 'zip', '-qr', dir .. '/a-1.0-sources.jar', 'org' }, { cwd = dir .. '/src' }):wait()
  return dir .. '/a-1.0.jar'
end

T['class_source()']['reads the Kotlin source of a class from the sources jar'] = function()
  eq(jdk_source.class_source(sources_fixture(), 'org/x/Y.class'), 'class Y\n')
end

T['class_source()']['maps a nested class to its outer class source'] = function()
  eq(jdk_source.class_source(sources_fixture(), 'org/x/Y$Inner.class'), 'class Y\n')
end

T['class_source()']['is nil when the sources jar has no such class'] = function() eq(jdk_source.class_source(sources_fixture(), 'org/x/Z.class'), nil) end

return T
