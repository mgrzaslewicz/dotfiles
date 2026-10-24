-- `:checkhealth custom`: checks for this config that no plugin covers.
--
-- The host nvim is installed independently of this repo (its mise.toml is not deployed), so the config records the
-- version the tests ran on and warns here, not at startup, when the running nvim differs.
-- Tests: tests/test_health.lua (also keeps `tested_version` equal to the repo's mise.toml pin).
--
-- It also lists the external programs the config needs beyond what `:checkhealth mason` / `nvim-treesitter` check.
-- `missing()` is shared with the e2e preflight (tests/e2e/preflight.lua), which stops before installing anything.

local M = {}

M.tested_version = '0.12.6'

-- jdtls v1.63 bundles Eclipse plugins that require JavaSE 25; kotlin-lsp and the debug adapters run on the same java.
local min_java = 25

---@class custom.Requirement
---@field name string executable
---@field why string
---@field hint string how to install

---@type custom.Requirement[]
M.requirements = {
  { name = 'java', why = ('jdtls, kotlin-lsp and the debug adapters run on it (%d+)'):format(min_java), hint = 'mise use -g java@temurin-25' },
  { name = 'python3', why = "Mason's jdtls launcher is a Python script", hint = 'apt install python3' },
  { name = 'unzip', why = 'Mason extracts kotlin-debug-adapter and other .zip packages', hint = 'apt install unzip' },
  { name = 'tree-sitter', why = 'nvim-treesitter builds parsers with the tree-sitter CLI', hint = 'mise use -g tree-sitter' },
  { name = 'cc', why = 'nvim-treesitter compiles parsers with a C compiler', hint = 'apt install gcc' },
}

--- Major version from `java -version` output (`"21.0.13"` -> 21, `"1.8.0_402"` -> 8).
---@param output string
---@return integer|nil
function M.java_major(output)
  local version = output:match 'version "([^"]+)"'
  if not version then return nil end
  local major, minor = version:match '^(%d+)%.?(%d*)'
  major = tonumber(major)
  if major == 1 then return tonumber(minor) end
  return major
end

---@class custom.Problem
---@field name string
---@field message string
---@field hint string

---@class custom.HealthEnv
---@field executable? fun(name: string): boolean
---@field java_version_output? fun(): string

--- Requirements not met on this machine. `env` replaces the lookups in tests.
---@param env? custom.HealthEnv
---@return custom.Problem[]
function M.missing(env)
  env = env or {}
  local executable = env.executable or function(name) return vim.fn.executable(name) == 1 end
  local java_version_output = env.java_version_output
    or function()
      local result = vim.system({ 'java', '-version' }, { text = true }):wait()
      return (result.stderr or '') .. (result.stdout or '')
    end

  local problems = {}
  for _, req in ipairs(M.requirements) do
    if not executable(req.name) then
      table.insert(problems, { name = req.name, message = ('%s not found: %s'):format(req.name, req.why), hint = req.hint })
    elseif req.name == 'java' then
      local major = M.java_major(java_version_output())
      if not major or major < min_java then
        local message = ('java %s found, %d+ needed: %s'):format(major or '(unknown version)', min_java, req.why)
        table.insert(problems, { name = 'java', message = message, hint = req.hint })
      end
    end
  end
  return problems
end

-- Without build metadata (`+v0.12.6`); a prerelease (`-dev`) never equals a release.
local function running_version()
  local v = vim.version()
  return ('%d.%d.%d'):format(v.major, v.minor, v.patch) .. (v.prerelease and ('-' .. v.prerelease) or '')
end

function M.check()
  vim.health.start 'Neovim version'
  local running = running_version()
  if running == M.tested_version then
    vim.health.ok(('Neovim %s is the tested version'):format(running))
  else
    vim.health.warn(('Neovim %s differs from the tested %s'):format(running, M.tested_version), {
      ('Install the tested version: `mise use -g neovim@%s`'):format(M.tested_version),
      'Or move the pin: change neovim in the dotfiles mise.toml and tested_version here, then `mise run check`',
    })
  end

  vim.health.start 'Prerequisites'
  local problems = {}
  for _, p in ipairs(M.missing()) do
    problems[p.name] = p
  end
  for _, req in ipairs(M.requirements) do
    local p = problems[req.name]
    if p then
      vim.health.warn(('%s: %s'):format(req.name, p.message), { p.hint })
    else
      vim.health.ok(('%s: %s'):format(req.name, req.why))
    end
  end
end

return M
