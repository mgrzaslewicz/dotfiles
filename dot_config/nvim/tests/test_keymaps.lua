-- Keymap prefix registry: every <leader> map of three or more keys belongs to a group below, and its desc starts with
-- the group's prefix, so which-key and `<leader>sk` read consistently. A new group starts here.
local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local groups = {
  u = 'Test: ',
  h = 'git ', -- gitsigns, per buffer
  g = 'Git: ',
  s = '[S]earch',
  t = '[T]oggle',
  r = 'Refactor: ', -- per LSP buffer
  d = 'Debug: ',
  b = 'Task: ',
  w = 'Session: ',
}

local child = helpers.new_child()

-- Records every vim.keymap.set of a <leader> map from the very start (before init.lua), so maps that are set twice
-- show up, not only the last one.
local record = [[
  _G.leader_maps = {}
  local set = vim.keymap.set
  vim.keymap.set = function(modes, lhs, rhs, opts)
    local key = lhs:gsub('<[Ll]eader>', ' ')
    if key:sub(1, 1) == ' ' then
      local buffer = opts and (opts.buffer or opts.buf)
      if buffer == true or buffer == 0 then buffer = vim.api.nvim_get_current_buf() end
      for _, mode in ipairs(type(modes) == 'table' and modes or { modes }) do
        table.insert(_G.leader_maps, { mode = mode == 'v' and 'x' or mode, lhs = key, desc = opts and opts.desc, buffer = buffer })
      end
    end
    return set(modes, lhs, rhs, opts)
  end
]]

-- Full startup, then the per-buffer maps: a file in a git repo (gitsigns) with an LSP client attached.
local function all_leader_maps()
  local repo = helpers.tree { ['Foo.kt'] = 'fun main() {}' }
  vim.system({ 'sh', '-c', 'git init -q && git add . && git -c user.name=t -c user.email=t@t commit -qm init && echo "// x" >> Foo.kt' }, { cwd = repo }):wait()
  child.start { '--cmd', 'lua ' .. record:gsub('\n', ' ') }
  child.cmd('edit ' .. repo .. '/Foo.kt')
  child.lua "vim.wait(5000, function() return vim.fn.maparg(' hs', 'n') ~= '' end)"
  helpers.attach_fake_lsp(child)
  return child.lua_get '_G.leader_maps'
end

local T = MiniTest.new_set { hooks = { post_case = function() child.stop() end } }

T['<leader> maps are in a registered group and carry its desc prefix'] = function()
  local maps = all_leader_maps()
  local seen = {}
  for _, m in ipairs(maps) do
    seen[m.lhs:sub(2, 2)] = true
  end
  -- The setup above really reached every group.
  for key in pairs(groups) do
    eq({ key, seen[key] }, { key, true })
  end

  local wrong = {}
  for _, m in ipairs(maps) do
    local prefix = groups[m.lhs:sub(2, 2)]
    if #m.lhs >= 3 and not (prefix and vim.startswith(m.desc or '', prefix)) then
      table.insert(wrong, ('%s %q %s'):format(m.mode, m.lhs, m.desc or '<no desc>'))
    end
  end
  eq(wrong, {})
end

T['no <leader> map is set twice or shadows a global one'] = function()
  local count, global = {}, {}
  for _, m in ipairs(all_leader_maps()) do
    local id = ('%s %q'):format(m.mode, m.lhs)
    local scoped = m.buffer and ('%s (buffer %d)'):format(id, m.buffer) or id
    count[scoped] = (count[scoped] or 0) + 1
    if not m.buffer then global[id] = true end
  end
  local dups = {}
  for scoped, n in pairs(count) do
    if n > 1 then table.insert(dups, scoped) end
    local id = scoped:match '^(.*) %(buffer %d+%)$'
    if id and global[id] then table.insert(dups, scoped .. ' shadows global') end
  end
  table.sort(dups)
  eq(dups, {})
end

return T
