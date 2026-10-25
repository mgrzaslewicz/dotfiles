-- codediff.nvim's native diff library and diff view in a temp git repository (no fixture project).
local e2e = require 'tests.e2e.helpers'
local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()
local T = MiniTest.new_set { hooks = { post_case = function() child.stop() end } }

local function git(repo, args)
  eq(vim.system(vim.list_extend({ 'git', '-c', 'user.name=e2e', '-c', 'user.email=e2e@example.com' }, args), { cwd = repo }):wait().code, 0)
end

T['codediff | git | downloads its library on first use, <leader>gd shows HEAD next to the working file'] = function()
  -- First use: no library yet. The plugin keeps it in its own directory.
  local plugin = vim.fs.joinpath(vim.env.XDG_DATA_HOME, 'nvim', 'site', 'pack', 'core', 'opt', 'codediff.nvim')
  for _, lib in ipairs(vim.fn.glob(plugin .. '/libvscode_diff_*.so', false, true)) do
    vim.fn.delete(lib)
  end

  local repo = helpers.tree { ['hello.txt'] = 'one\ntwo\nthree' }
  git(repo, { 'init', '-q' })
  git(repo, { 'add', '.' })
  git(repo, { 'commit', '-qm', 'init' })
  vim.fn.writefile({ 'one', 'TWO', 'three' }, repo .. '/hello.txt')

  child.start { '--cmd', 'cd ' .. repo }
  e2e.wait(child, 'build', 'codediff library downloaded', ('#vim.fn.glob(%q, false, true) == 1'):format(plugin .. '/libvscode_diff_*.so'))
  eq(child.lua_get "require('neogit.config').values.diff_viewer", 'codediff')

  child.cmd 'edit hello.txt'
  child.type_keys ' gd'
  e2e.wait(child, 'edit', 'codediff tab with three windows', '#vim.api.nvim_list_tabpages() == 2 and #vim.api.nvim_tabpage_list_wins(0) == 3')
  local view = child.lua [[
    return vim.tbl_map(function(win)
      local buf = vim.api.nvim_win_get_buf(win)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      return vim.bo[buf].filetype == 'codediff-explorer' and { 'explorer', vim.trim(lines[2]) } or { vim.fs.basename(vim.api.nvim_buf_get_name(buf)), lines }
    end, vim.api.nvim_tabpage_list_wins(0))
  ]]
  eq(view, { { 'explorer', 'hello.txt                           M' }, { 'hello.txt', { 'one', 'two', 'three' } }, { 'hello.txt', { 'one', 'TWO', 'three' } } })
  eq(child.lua_get "vim.api.nvim_exec2('messages', { output = true }).output:find('rror') == nil", true)
end

return T
