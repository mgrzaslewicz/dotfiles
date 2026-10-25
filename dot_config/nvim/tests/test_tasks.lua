local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set {
  hooks = {
    pre_case = function() child.start() end,
    post_case = function() child.stop() end,
  },
}

-- Templates overseer offers in `dir`, from our gradle/maven provider only: name -> builder result.
local function jvm_tasks(dir)
  return child.lua(
    [[
    local found
    require('overseer.template').list({ dir = ... }, function(templates) found = templates end)
    vim.wait(5000, function() return found ~= nil end)
    local ret = {}
    for _, t in ipairs(found) do
      if t.name:match '^gradle ' or t.name:match '^mvn ' then
        local task = t.builder { args = { 'help' } }
        ret[t.name] = { cmd = task.cmd, cwd = task.cwd, efm = task.components[1].errorformat, strategy = task.strategy and { task.strategy[1], task.strategy.use_terminal } }
      end
    end
    return ret
  ]],
    { dir }
  )
end

T['gradle/maven provider offers Gradle tasks at the build root'] = function()
  local dir = helpers.tree { gradlew = '', ['settings.gradle.kts'] = '', ['app/build.gradle.kts'] = '' }
  local tasks = jvm_tasks(dir .. '/app')
  local names = vim.tbl_keys(tasks)
  table.sort(names)
  eq(names, { 'gradle build', 'gradle check', 'gradle classes', 'gradle clean', 'gradle run', 'gradle test', 'gradle …' })
  eq(tasks['gradle build'].cmd, { './gradlew', 'build' })
  eq(tasks['gradle build'].cwd, dir)
  eq(tasks['gradle …'].cmd, { './gradlew', 'help' })
end

T['gradle/maven provider adds Spring Boot tasks'] = function()
  local dir = helpers.tree { ['pom.xml'] = '<groupId>org.springframework.boot</groupId>' }
  eq(jvm_tasks(dir)['mvn spring-boot:run'].cmd, { 'mvn', 'spring-boot:run' })
end

T['gradle/maven tasks fill the quickfix list through the JVM errorformat'] = function()
  local dir = helpers.tree { ['build.gradle'] = '' }
  local efm = child.lua_get "require 'custom.jvm.errorformat'"
  eq(jvm_tasks(dir)['gradle test'].efm, efm)
end

-- Overseer re-parses the output buffer on exit; a terminal buffer wraps long lines (absolute paths) at its width.
T['gradle/maven tasks write to a plain buffer, so long error lines stay whole'] = function()
  local dir = helpers.tree { ['pom.xml'] = '' }
  local tasks = jvm_tasks(dir)
  eq(tasks['mvn compile'].strategy, { 'jobstart', false })
  eq(tasks['mvn …'].strategy, { 'jobstart', false })
end

-- Gradle and Maven repeat compiler errors in their failure summary; IntelliJ lists each error once.
T['gradle/maven tasks list each compiler error once'] = function()
  local dir = helpers.tree { ['pom.xml'] = '' }
  local output = table.concat({
    '[ERROR] COMPILATION ERROR :',
    '[ERROR] ' .. dir .. '/src/main/java/Foo.java:[4,24] cannot find symbol',
    '[ERROR] ' .. dir .. '/src/main/java/Foo.java:[7,1] class, interface, enum, or record expected',
    '[ERROR] Failed to execute goal org.apache.maven.plugins:maven-compiler-plugin:3.16.0:compile: Compilation failure: ',
    '[ERROR] ' .. dir .. '/src/main/java/Foo.java:[4,24] cannot find symbol',
    '[ERROR] ' .. dir .. '/src/main/java/Foo.java:[7,1] class, interface, enum, or record expected',
  }, '\n')
  local items = child.lua(
    [[
    local dir, output = ...
    local found
    require('overseer.template').list({ dir = dir }, function(templates) found = templates end)
    vim.wait(5000, function() return found ~= nil end)
    local template = vim.iter(found):find(function(t) return t.name == 'mvn compile' end)
    local definition = template.builder {}
    definition.cmd = { 'printf', '%s\\n', output }
    local task = require('overseer').new_task(definition)
    task:start()
    vim.wait(5000, function() return task:is_complete() end)
    vim.wait(100)
    return vim.tbl_map(function(i) return { lnum = i.lnum, text = i.text } end, vim.fn.getqflist())
  ]],
    { dir, output }
  )
  eq(items, { { lnum = 4, text = 'cannot find symbol' }, { lnum = 7, text = 'class, interface, enum, or record expected' } })
end

return T
