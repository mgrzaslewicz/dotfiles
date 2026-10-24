-- Gradle/Maven project detection, shared by tasks (custom/plugins/tasks.lua) and Kotlin debug
-- (custom/plugins/debug.lua). Pure: no side effects on require, paths in, answers out.
--
-- IntelliJ terms: the project is the whole build (where the wrapper or settings file lives), a module is
-- one build file below it. Tests: tests/test_project.lua.

local M = {}

-- Search order matters: a subproject has its own build file, but the wrapper (or settings file) marks the root.
local root_markers = {
  { 'gradlew', 'mvnw' },
  { 'settings.gradle.kts', 'settings.gradle' },
  { 'build.gradle.kts', 'build.gradle', 'pom.xml' },
}

--- The build (IntelliJ project) containing `dir`: nearest wrapper, else settings file, else build file, searching up;
--- a Maven module's build is its topmost parent pom.xml. Tasks run there and the JVM language servers use it as root.
---@param dir string
---@return { tool: 'gradle'|'maven', root: string, cmd: string }|nil
function M.root(dir)
  for _, names in ipairs(root_markers) do
    local marker = vim.fs.find(names, { upward = true, path = dir })[1]
    if marker then
      local name = vim.fs.basename(marker)
      local tool = (name == 'mvnw' or name == 'pom.xml') and 'maven' or 'gradle'
      local cmd = ({ gradlew = './gradlew', mvnw = './mvnw' })[name] or (tool == 'maven' and 'mvn' or 'gradle')
      local root = vim.fs.dirname(marker)
      -- A module's pom.xml is not the build: climb to the topmost pom.xml of an unbroken chain of parents.
      if name == 'pom.xml' then
        while vim.uv.fs_stat(vim.fs.joinpath(vim.fs.dirname(root), 'pom.xml')) do
          root = vim.fs.dirname(root)
        end
      end
      return { tool = tool, root = root, cmd = cmd }
    end
  end
end

--- kotlin-debug-adapter's `projectRoot`: each marker in turn, searched all the way up. For Gradle that is the
--- build root, for Maven the nearest module. Kept as it was; whether the adapter wants the module or the
--- whole build is still open.
---@param source string|integer directory, or buffer as for |vim.fs.root()|
---@return string|nil
function M.debug_root(source) return vim.fs.root(source, { 'settings.gradle.kts', 'settings.gradle', 'gradlew', 'pom.xml' }) end

--- Whether the root or a subproject build file (two levels deep) applies the Spring Boot plugin or parent.
---@param root string
---@return boolean
function M.uses_spring_boot(root)
  local skip = function(dir) return not dir:match '^%.' and dir ~= 'build' and dir ~= 'target' and dir ~= 'node_modules' end
  for path, type in vim.fs.dir(root, { depth = 2, skip = skip }) do
    local name = vim.fs.basename(path)
    if type == 'file' and (name:match '^build%.gradle' or name == 'pom.xml') then
      local content = table.concat(vim.fn.readfile(vim.fs.joinpath(root, path)), '\n')
      if content:find('org.springframework.boot', 1, true) then return true end
    end
  end
  return false
end

return M
