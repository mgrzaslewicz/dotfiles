local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local function version()
  local v = vim.version()
  return ('%d.%d.%d'):format(v.major, v.minor, v.patch)
end

-- The repo's mise.toml pins the nvim the tests run on (tests/run.sh); the deployed config cannot read it
-- (chezmoi-ignored), so it carries a copy that must follow every pin bump.
T['tested version follows the mise.toml neovim pin'] = function()
  local mise = table.concat(vim.fn.readfile '../../mise.toml', '\n')
  local pin = mise:match '\nneovim%s*=%s*"([^"]+)"'
  eq(require('custom.health').tested_version, pin)
  eq(version(), pin)
end

local child = helpers.new_child()

T[':checkhealth custom'] = MiniTest.new_set {
  hooks = {
    pre_case = function() child.start() end,
    post_case = function() child.stop() end,
  },
}

local function checkhealth()
  child.cmd 'checkhealth custom'
  return table.concat(child.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
end

T[':checkhealth custom']['is OK on the tested nvim version'] = function()
  local report = checkhealth()
  eq(report:find('OK Neovim ' .. version() .. ' is the tested version', 1, true) ~= nil, true)
  eq(report:find('WARNING', 1, true), nil)
end

T[':checkhealth custom']['warns on any other version'] = function()
  child.lua "require('custom.health').tested_version = '0.11.0'"
  local report = checkhealth()
  eq(report:find('WARNING Neovim ' .. version() .. ' differs from the tested 0.11.0', 1, true) ~= nil, true)
end

return T
