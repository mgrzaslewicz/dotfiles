local helpers = require 'tests.helpers'
local tree = helpers.tree
local autosave = require 'custom.autosave'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['session_enabled()'] = MiniTest.new_set()

T['session_enabled()']['is on without startup arguments'] = function() eq(autosave.session_enabled {}, true) end

T['session_enabled()']['is on when started on a directory'] = function()
  local dir = tree { ['src/'] = '' }
  eq(autosave.session_enabled { dir }, true)
end

T['session_enabled()']['is off when started on a file'] = function()
  local dir = tree { ['Foo.kt'] = '' }
  eq(autosave.session_enabled { dir .. '/Foo.kt' }, false)
end

T['session_enabled()']['is off when any startup argument is a file'] = function()
  local dir = tree { ['src/'] = '', ['Foo.kt'] = '' }
  eq(autosave.session_enabled { dir, dir .. '/Foo.kt' }, false)
end

T['is_project_file()'] = MiniTest.new_set()

T['is_project_file()']['is true for a file in a git repo'] = function()
  local dir = tree { ['.git/'] = '', ['src/Foo.kt'] = '' }
  eq(autosave.is_project_file(dir .. '/src/Foo.kt'), true)
end

T['is_project_file()']['is true for a file in a Gradle build without git'] = function()
  local dir = tree { ['settings.gradle.kts'] = '', ['app/src/Foo.kt'] = '' }
  eq(autosave.is_project_file(dir .. '/app/src/Foo.kt'), true)
end

T['is_project_file()']['is false for a file outside any project'] = function()
  local dir = tree { ['notes/todo.txt'] = '' }
  eq(autosave.is_project_file(dir .. '/notes/todo.txt'), false)
end

T['is_project_file()']['is false for an unnamed buffer'] = function() eq(autosave.is_project_file '', false) end

local child = helpers.new_child()

local T_smoke = MiniTest.new_set { hooks = { post_case = function() child.stop() end } }

-- Types a char at the start of the buffer and leaves insert mode: the autosave trigger.
local function edit_and_leave(path)
  child.cmd('edit ' .. path)
  child.type_keys('i', 'x', '<Esc>')
end

-- Waits in the child until the file on disk holds `text` as its first line (the debounced save has run).
local function wait_saved(path, text)
  child.lua([[ local path, text = ...; vim.wait(3000, function() return vim.fn.readfile(path)[1] == text end) ]], { path, text })
end

T_smoke['saves a project file on leaving insert mode when started without a file'] = function()
  local repo = tree { ['.git/'] = '', ['Foo.kt'] = 'fun main() {}' }
  child.start()
  edit_and_leave(repo .. '/Foo.kt')
  wait_saved(repo .. '/Foo.kt', 'xfun main() {}')
  eq(vim.fn.readfile(repo .. '/Foo.kt'), { 'xfun main() {}' })
end

T_smoke['debounces the save: nothing is written before 1000ms of quiet'] = function()
  local repo = tree { ['.git/'] = '', ['Foo.kt'] = 'fun main() {}' }
  child.start()
  edit_and_leave(repo .. '/Foo.kt')
  eq(vim.fn.readfile(repo .. '/Foo.kt'), { 'fun main() {}' })
  wait_saved(repo .. '/Foo.kt', 'xfun main() {}')
  eq(vim.fn.readfile(repo .. '/Foo.kt'), { 'xfun main() {}' })
end

T_smoke['does not save when started with a file'] = function()
  local repo = tree { ['.git/'] = '', ['Foo.kt'] = 'fun main() {}' }
  child.start { repo .. '/Foo.kt' }
  edit_and_leave(repo .. '/Foo.kt')
  eq(vim.fn.readfile(repo .. '/Foo.kt'), { 'fun main() {}' })
end

T_smoke['does not save a file outside any project'] = function()
  local dir = tree { ['notes.txt'] = 'todo' }
  child.start()
  edit_and_leave(dir .. '/notes.txt')
  eq(vim.fn.readfile(dir .. '/notes.txt'), { 'todo' })
end

T_smoke['<leader>ta turns autosave off and on'] = function()
  local repo = tree { ['.git/'] = '', ['Foo.kt'] = 'fun main() {}' }
  child.start()
  child.type_keys(' ', 't', 'a')
  edit_and_leave(repo .. '/Foo.kt')
  child.lua 'vim.wait(1500, function() return false end)'
  eq(vim.fn.readfile(repo .. '/Foo.kt'), { 'fun main() {}' })
  child.type_keys(' ', 't', 'a')
  child.type_keys('i', 'y', '<Esc>')
  wait_saved(repo .. '/Foo.kt', 'yxfun main() {}')
  eq(vim.fn.readfile(repo .. '/Foo.kt'), { 'yxfun main() {}' })
end

T_smoke['<leader>ta can turn autosave on in a session started on a file'] = function()
  local repo = tree { ['.git/'] = '', ['Foo.kt'] = 'fun main() {}' }
  child.start { repo .. '/Foo.kt' }
  child.type_keys(' ', 't', 'a')
  edit_and_leave(repo .. '/Foo.kt')
  wait_saved(repo .. '/Foo.kt', 'xfun main() {}')
  eq(vim.fn.readfile(repo .. '/Foo.kt'), { 'xfun main() {}' })
end

T['in nvim'] = T_smoke

return T
