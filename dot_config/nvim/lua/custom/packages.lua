-- Driver for dot_local/bin/executable_nvim-packages, which runs it headless:
--   update: plugins to the latest `version` in nvim-pack-lock.json, Mason pins to the registry's latest (lua/custom/tools.lua)
--   sync:   plugins to the lockfile's revisions, Mason to the pins (drift() in custom/health.lua)
-- Vim.pack has no lockfile restore of its own in the sync path: `target = 'lockfile'` is what does it.
-- The pure helpers are unit tested in tests/test_packages.lua; the rest needs the real plugins and network.

local M = {}

--- Replace the version of one `{ 'name', version = '...' }` entry in custom/tools.lua source text.
---@param text string
---@param name string
---@param version string
---@return string
function M.set_pin(text, name, version)
  local start, stop = text:find(("{ '%s', version = '"):format(name), 1, true)
  if not start then error(('no pin for %s'):format(name)) end
  local value_end = assert(text:find("'", stop + 1, true), ('unterminated pin for %s'):format(name))
  return text:sub(1, stop) .. version .. text:sub(value_end)
end

-- Major (first number) changed, or minor changed below 1.0 where minor bumps are breaking. Unparseable versions are not flagged.
---@param from string
---@param to string
---@return boolean
function M.is_major(from, to)
  local function parts(v)
    local major, minor = v:match '^v?(%d+)%.(%d+)'
    return tonumber(major), tonumber(minor)
  end
  local fm, fn = parts(from)
  local tm, tn = parts(to)
  if not fm or not tm then return false end
  return fm ~= tm or (fm == 0 and fn ~= tn)
end

---@class custom.PinChange
---@field name string
---@field from string
---@field to string
---@field major boolean

--- Mason pins whose version moved between two pin lists (`{ name, version = ... }` entries).
---@param old table[]
---@param new table[]
---@return custom.PinChange[]
function M.pin_changes(old, new)
  local before = {}
  for _, tool in ipairs(old) do
    before[tool[1]] = tool.version
  end
  local changes = {}
  for _, tool in ipairs(new) do
    local from = before[tool[1]]
    if from and from ~= tool.version then table.insert(changes, { name = tool[1], from = from, to = tool.version, major = M.is_major(from, tool.version) }) end
  end
  return changes
end

--- Plugins whose lockfile revision moved or that are new, sorted by name. `from` is nil for a new plugin.
---@param old table<string, { rev: string }>
---@param new table<string, { rev: string }>
---@return { name: string, from: string|nil, to: string }[]
function M.plugin_changes(old, new)
  local changes = {}
  for name, spec in pairs(new) do
    local from = old[name] and old[name].rev
    if from ~= spec.rev then table.insert(changes, { name = name, from = from, to = spec.rev }) end
  end
  table.sort(changes, function(a, b) return a.name < b.name end)
  return changes
end

local function short(rev) return rev and rev:sub(1, 8) or 'new' end

--- Commit body: one line per changed plugin and Mason pin.
---@param pins custom.PinChange[]
---@param plugins { name: string, from: string|nil, to: string }[]
---@return string
function M.report(pins, plugins)
  local lines = {}
  for _, c in ipairs(plugins) do
    table.insert(lines, ('- plugin %s: %s → %s'):format(c.name, short(c.from), short(c.to)))
  end
  for _, c in ipairs(pins) do
    table.insert(lines, ('- mason %s: %s → %s%s'):format(c.name, c.from, c.to, c.major and ' (major)' or ''))
  end
  return table.concat(lines, '\n')
end

-- Driver: everything below runs in headless nvim (see executable_nvim-packages). Not unit tested.

local function read_file(path)
  local f = assert(io.open(path, 'r'))
  local text = f:read '*a'
  f:close()
  return text
end

local function write_file(path, text)
  local f = assert(io.open(path, 'w'))
  f:write(text)
  f:close()
end

local function read_plugins(lock_path) return vim.json.decode(read_file(lock_path)).plugins end

-- Registry refresh is what makes get_latest_version() newer than the last refresh.
local function refresh_registry()
  local registry = require 'mason-registry'
  local done, failure
  registry.refresh(function(success, err)
    done = true
    if not success then failure = tostring(err) end
  end)
  vim.wait(300000, function() return done end, 200)
  if not done or failure then error('mason registry refresh failed: ' .. tostring(failure or 'timed out')) end
end

local function latest_version(name)
  local registry = require 'mason-registry'
  local ok, pkg = pcall(registry.get_package, name)
  if not ok then return nil end
  local ok_version, version = pcall(pkg.get_latest_version, pkg)
  return ok_version and version or nil
end

--- Update mode. Writes new pins and lockfile, and the commit body to `report_path`.
---@param report_path string
function M.update(report_path)
  local config = vim.fn.stdpath 'config'
  local lock_path = config .. '/nvim-pack-lock.json'
  local tools_path = config .. '/lua/custom/tools.lua'

  local plugins_before = read_plugins(lock_path)
  local old_pins = vim.deepcopy(require('custom.tools').mason)

  vim.pack.update(nil, { force = true })
  refresh_registry()

  local text = read_file(tools_path)
  local new_pins = {}
  for _, tool in ipairs(old_pins) do
    local latest = latest_version(tool[1]) or tool.version
    table.insert(new_pins, { tool[1], version = latest })
    if latest ~= tool.version then text = M.set_pin(text, tool[1], latest) end
  end
  write_file(tools_path, text)

  local pins = M.pin_changes(old_pins, new_pins)
  local plugins = M.plugin_changes(plugins_before, read_plugins(lock_path))
  write_file(report_path, M.report(pins, plugins) .. '\n')
end

--- Waits for a Mason install at `version`. Returns false and the error when it fails or times out.
local function install_pin(name, version)
  local pkg = require('mason-registry').get_package(name)
  local done, failure
  pkg:install({ version = version, force = true }, function(success, err)
    done = true
    if not success then failure = tostring(err) end
  end)
  vim.wait(900000, function() return done end, 500)
  if not done then return false, 'timed out' end
  return failure == nil, failure
end

--- Sync mode. Plugins to the lockfile revisions, Mason packages that differ from their pins. Returns what failed.
---@return string[]
function M.sync()
  local failed = {}
  local ok, err = pcall(vim.pack.update, nil, { offline = true, target = 'lockfile', force = true })
  if not ok then table.insert(failed, 'plugins: ' .. tostring(err)) end
  for _, drift in ipairs(require('custom.health').drift()) do
    local called, success, why = pcall(install_pin, drift.name, drift.pinned)
    if not called then
      table.insert(failed, ('mason %s@%s: %s'):format(drift.name, drift.pinned, tostring(success)))
    elseif not success then
      table.insert(failed, ('mason %s@%s: %s'):format(drift.name, drift.pinned, tostring(why)))
    end
  end
  return failed
end

--- Headless entry points: report the result and quit with a status the script can check.
function M.update_main(report_path)
  local ok, err = pcall(M.update, report_path)
  if not ok then
    io.stderr:write(tostring(err), '\n')
    vim.cmd 'cquit 1'
  end
  vim.cmd 'qall!'
end

function M.sync_main()
  local failed = M.sync()
  if #failed > 0 then
    io.stderr:write('nvim-packages sync failed:\n  ', table.concat(failed, '\n  '), '\n')
    vim.cmd 'cquit 1'
  end
  print 'nvim-packages: host matches dotfiles'
  vim.cmd 'qall!'
end

return M
