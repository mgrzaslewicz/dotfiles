local tree = require('tests.helpers').tree
local project = require 'custom.jvm.project'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['root()'] = MiniTest.new_set()

T['root()']['finds the Gradle wrapper from a subproject'] = function()
  local dir = tree { gradlew = '', ['settings.gradle.kts'] = '', ['app/build.gradle.kts'] = '', ['app/src/main/kotlin/'] = '' }
  eq(project.root(dir .. '/app/src/main/kotlin'), { tool = 'gradle', root = dir, cmd = './gradlew' })
end

T['root()']['finds the Maven wrapper from a submodule'] = function()
  local dir = tree { mvnw = '', ['pom.xml'] = '', ['core/pom.xml'] = '', ['core/src/main/java/'] = '' }
  eq(project.root(dir .. '/core/src/main/java'), { tool = 'maven', root = dir, cmd = './mvnw' })
end

T['root()']['finds a wrapper-less Gradle build by its settings file, not the subproject build file'] = function()
  local dir = tree { ['settings.gradle'] = '', ['app/build.gradle'] = '', ['app/src/'] = '' }
  eq(project.root(dir .. '/app/src'), { tool = 'gradle', root = dir, cmd = 'gradle' })
end

T['root()']['finds a wrapper-less single-module Gradle build by its build file'] = function()
  local dir = tree { ['build.gradle.kts'] = '', ['src/'] = '' }
  eq(project.root(dir .. '/src'), { tool = 'gradle', root = dir, cmd = 'gradle' })
end

T['root()']['finds a wrapper-less Maven build by the nearest pom.xml'] = function()
  local dir = tree { ['pom.xml'] = '', ['src/main/java/'] = '' }
  eq(project.root(dir .. '/src/main/java'), { tool = 'maven', root = dir, cmd = 'mvn' })
end

T['root()']['returns nil outside a project'] = function()
  local dir = tree { ['src/'] = '' }
  eq(project.root(dir .. '/src'), nil)
end

-- Today's Kotlin debug `projectRoot`: markers tried in order, each searched all the way up. Whether
-- kotlin-debug-adapter wants the module or the whole build is open (layer B).
T['debug_root()'] = MiniTest.new_set()

T['debug_root()']['is the Gradle build root, even from a subproject with its own build file'] = function()
  local dir = tree { gradlew = '', ['settings.gradle.kts'] = '', ['app/build.gradle.kts'] = '', ['app/src/'] = '' }
  eq(project.debug_root(dir .. '/app/src'), dir)
end

T['debug_root()']['is the nearest Maven module, even under a wrapper'] = function()
  local dir = tree { mvnw = '', ['pom.xml'] = '', ['core/pom.xml'] = '', ['core/src/'] = '' }
  eq(project.debug_root(dir .. '/core/src'), dir .. '/core')
end

T['debug_root()']['returns nil outside a project'] = function()
  local dir = tree { ['src/'] = '' }
  eq(project.debug_root(dir .. '/src'), nil)
end

T['uses_spring_boot()'] = MiniTest.new_set()

local boot_plugin = 'plugins { id("org.springframework.boot") version "3.3.0" }'

T['uses_spring_boot()']['finds the plugin in the root build file'] = function() eq(project.uses_spring_boot(tree { ['build.gradle.kts'] = boot_plugin }), true) end

T['uses_spring_boot()']['finds the plugin in a subproject build file'] = function()
  eq(project.uses_spring_boot(tree { ['settings.gradle.kts'] = '', ['app/build.gradle.kts'] = boot_plugin }), true)
end

T['uses_spring_boot()']['finds the parent in a Maven submodule pom.xml'] = function()
  local pom = '<parent><groupId>org.springframework.boot</groupId></parent>'
  eq(project.uses_spring_boot(tree { ['pom.xml'] = '', ['web/pom.xml'] = pom }), true)
end

T['uses_spring_boot()']['is false without the plugin'] = function()
  eq(project.uses_spring_boot(tree { ['build.gradle.kts'] = 'plugins { kotlin("jvm") }' }), false)
end

T['uses_spring_boot()']['skips build output, dependencies and dot dirs'] = function()
  local dir = tree {
    ['pom.xml'] = '',
    ['build/pom.xml'] = boot_plugin,
    ['target/pom.xml'] = boot_plugin,
    ['node_modules/pom.xml'] = boot_plugin,
    ['.gradle/build.gradle'] = boot_plugin,
  }
  eq(project.uses_spring_boot(dir), false)
end

return T
