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
        ret[t.name] = { cmd = task.cmd, cwd = task.cwd, efm = task.components[1].errorformat }
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

return T
