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

T['missing()'] = MiniTest.new_set()

local health = require 'custom.health'

-- Everything present, java 25 unless given.
local function env(overrides)
  return vim.tbl_extend('force', {
    executable = function() return true end,
    java_version_output = function() return 'openjdk version "25.0.5" 2026-10-21 LTS' end,
  }, overrides or {})
end

local function names(problems)
  return vim.tbl_map(function(p) return p.name end, problems)
end

T['missing()']['is empty when everything is installed'] = function() eq(health.missing(env()), {}) end

T['missing()']['names a missing executable with an install hint'] = function()
  local problems = health.missing(env { executable = function(name) return name ~= 'unzip' end })
  eq(names(problems), { 'unzip' })
  eq(problems[1].hint ~= nil, true)
end

-- jdtls v1.63 bundles Eclipse 4.38 plugins that require JavaSE 25 (found by tests/e2e).
T['missing()']['reports a java older than jdtls needs'] = function()
  local problems = health.missing(env { java_version_output = function() return 'openjdk version "21.0.13" 2026-10-20 LTS' end })
  eq(names(problems), { 'java' })
  eq(problems[1].message:find('java 21 found, 25+ needed', 1, true) ~= nil, true)
end

T['missing()']['reports missing java once, without a version check'] = function()
  local problems = health.missing(env { executable = function(name) return name ~= 'java' end })
  eq(names(problems), { 'java' })
end

T['java_major()'] = function()
  eq(health.java_major 'openjdk version "21.0.13" 2026-10-21 LTS', 21)
  eq(health.java_major 'java version "1.8.0_402"', 8)
  eq(health.java_major 'openjdk version "25" 2025-09-16', 25)
  eq(health.java_major 'command not found', nil)
end

-- tests/e2e/preflight.lua with PATH limited to fake programs: everything required except `without`.
local function preflight(without)
  local bin = helpers.tree { ['bin/'] = '' } .. '/bin'
  for _, req in ipairs(health.requirements) do
    if req.name ~= without then
      local path = vim.fs.joinpath(bin, req.name)
      local script = req.name == 'java' and 'echo \'openjdk version "25.0.5" 2026-10-20 LTS\' >&2' or 'true'
      vim.fn.writefile({ '#!/bin/sh', script }, path)
      vim.fn.setfperm(path, 'rwxr-xr-x')
    end
  end
  local start = vim.uv.hrtime()
  local result = vim.system({ vim.v.progpath, '--clean', '--headless', '-l', 'tests/e2e/preflight.lua' }, { env = { PATH = bin }, clear_env = true }):wait()
  return result, (vim.uv.hrtime() - start) / 1e9
end

T['e2e preflight'] = MiniTest.new_set()

T['e2e preflight']['passes with every prerequisite present'] = function() eq(preflight(nil).code, 0) end

T['e2e preflight']['fails fast naming a missing program and how to install it'] = function()
  local result, seconds = preflight 'unzip'
  eq(result.code, 1)
  eq(result.stderr:find('unzip not found', 1, true) ~= nil, true)
  eq(result.stderr:find('apt install unzip', 1, true) ~= nil, true)
  eq(seconds < 1, true)
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
  eq(report:find('WARNING Neovim', 1, true), nil)
end

T[':checkhealth custom']['lists the prerequisites'] = function()
  local report = checkhealth()
  for _, req in ipairs(health.requirements) do
    eq({ req.name, report:find(req.name .. ':', 1, true) ~= nil }, { req.name, true })
  end
end

T[':checkhealth custom']['warns on any other version'] = function()
  child.lua "require('custom.health').tested_version = '0.11.0'"
  local report = checkhealth()
  eq(report:find('WARNING Neovim ' .. version() .. ' differs from the tested 0.11.0', 1, true) ~= nil, true)
end

return T
