-- Task runner (IntelliJ Run Configurations / Gradle and Maven tool windows): overseer.nvim
-- https://github.com/stevearc/overseer.nvim
--
-- Gradle and Maven have no built-in overseer provider, so one is registered below. It offers the common
-- tasks for the project root (the nearest `gradlew`/`mvnw`, else build file, above the cwd) plus a free-form
-- "gradle …"/"mvn …" task. Compiler errors (javac, kotlinc, Maven) stream into the quickfix list.
-- Other runners (make, npm, cargo, just, mise, VS Code tasks.json) are built into overseer.

vim.pack.add { 'https://github.com/stevearc/overseer.nvim' }

local overseer = require 'overseer'
overseer.setup {}

-- javac:   /path/Foo.java:12: error: cannot find symbol
-- kotlinc: e: file:///path/Foo.kt:12:5 Unresolved reference 'x'   (Kotlin 1.8+; older: e: /path/Foo.kt: (12, 5): …)
-- Maven:   [ERROR] /path/Foo.java:[12,5] cannot find symbol         (kotlin-maven-plugin: [ERROR] file:///path/Foo.kt:12:5 …)
local errorformat = table.concat({
  '%f:%l: %trror: %m',
  '%f:%l: %tarning: %m',
  '%t: file://%f:%l:%c %m',
  '%t: %f: (%l\\, %c): %m',
  '[%tRROR] file://%f:%l:%c %m',
  '[%tARNING] file://%f:%l:%c %m',
  '[%tRROR] %f:[%l\\,%c] %m',
  '[%tARNING] %f:[%l\\,%c] %m',
}, ',')

local function components()
  return {
    { 'on_output_quickfix', errorformat = errorformat, items_only = true, open_on_exit = 'failure' },
    'default',
  }
end

-- Search order matters: a subproject has its own build file, but the wrapper (or settings file) marks the root.
local root_markers = {
  { 'gradlew', 'mvnw' },
  { 'settings.gradle.kts', 'settings.gradle' },
  { 'build.gradle.kts', 'build.gradle', 'pom.xml' },
}

---@param dir string
---@return { tool: 'gradle'|'maven', root: string, cmd: string }|nil
local function find_project(dir)
  for _, names in ipairs(root_markers) do
    local marker = vim.fs.find(names, { upward = true, path = dir })[1]
    if marker then
      local name = vim.fs.basename(marker)
      local tool = (name == 'mvnw' or name == 'pom.xml') and 'maven' or 'gradle'
      local cmd = ({ gradlew = './gradlew', mvnw = './mvnw' })[name] or (tool == 'maven' and 'mvn' or 'gradle')
      return { tool = tool, root = vim.fs.dirname(marker), cmd = cmd }
    end
  end
end

-- Looks at the root and subproject build files (two levels deep) for the Spring Boot plugin.
local function uses_spring_boot(root)
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

local tasks = {
  gradle = {
    { 'classes', overseer.TAG.BUILD },
    { 'build', overseer.TAG.BUILD },
    { 'test', overseer.TAG.TEST },
    { 'check', overseer.TAG.TEST },
    { 'clean', overseer.TAG.CLEAN },
    { 'run', overseer.TAG.RUN },
  },
  maven = {
    { 'compile', overseer.TAG.BUILD },
    { 'package', overseer.TAG.BUILD },
    { 'test', overseer.TAG.TEST },
    { 'verify', overseer.TAG.TEST },
    { 'clean', overseer.TAG.CLEAN },
    { 'install', overseer.TAG.BUILD },
  },
}

local spring_boot_tasks = {
  gradle = { { 'bootRun', overseer.TAG.RUN }, { 'bootRun --debug-jvm', overseer.TAG.RUN } },
  maven = { { 'spring-boot:run', overseer.TAG.RUN } },
}

overseer.register_template {
  name = 'gradle/maven',
  generator = function(opts)
    local project = find_project(opts.dir)
    if not project then return 'No Gradle or Maven project found' end
    local tool = project.tool == 'gradle' and 'gradle' or 'mvn'

    local list = vim.list_extend({}, tasks[project.tool])
    if uses_spring_boot(project.root) then vim.list_extend(list, spring_boot_tasks[project.tool]) end

    local ret = {}
    for _, task in ipairs(list) do
      local args, tag = task[1], task[2]
      table.insert(ret, {
        name = ('%s %s'):format(tool, args),
        tags = { tag },
        builder = function() return { cmd = vim.list_extend({ project.cmd }, vim.split(args, ' ')), cwd = project.root, components = components() } end,
      })
    end
    table.insert(ret, {
      name = tool .. ' …',
      desc = 'Run with custom arguments',
      params = { args = { type = 'list', delimiter = ' ', desc = 'e.g. :app:test --tests "*FooTest"' } },
      builder = function(params) return { cmd = vim.list_extend({ project.cmd }, params.args), cwd = project.root, components = components() } end,
    })
    return ret
  end,
}

local function restart_last()
  local recent = overseer.list_tasks {
    status = { overseer.STATUS.SUCCESS, overseer.STATUS.FAILURE, overseer.STATUS.CANCELED },
    sort = require('overseer.task_list').sort_finished_recently,
  }
  if vim.tbl_isempty(recent) then
    vim.notify('No finished tasks to rerun', vim.log.levels.WARN)
  else
    overseer.run_action(recent[1], 'restart')
  end
end

local function map(keys, func, desc) vim.keymap.set('n', keys, func, { desc = 'Task: ' .. desc }) end

map('<leader>bb', '<cmd>OverseerRun<CR>', 'Run task…')
map('<leader>bc', function() overseer.run_task { tags = { overseer.TAG.BUILD } } end, '[C]ompile (build tasks)')
map('<leader>bl', restart_last, 'Rerun [L]ast')
map('<leader>bt', '<cmd>OverseerToggle<CR>', '[T]oggle task list')
map('<leader>ba', '<cmd>OverseerTaskAction<CR>', 'Task [A]ction (restart, stop, output…)')
map('<leader>bs', ':OverseerShell ', 'Run [S]hell command…')
