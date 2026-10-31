-- `:checkhealth custom`: checks for this config that no plugin covers.
--
-- The host nvim is installed independently of this repo (its mise.toml is not deployed), so the config records the
-- version the tests ran on and warns here, not at startup, when the running nvim differs.
-- Tests: tests/test_health.lua (also keeps `tested_version` equal to the repo's mise.toml pin).
--
-- It also lists the external programs the config needs beyond what `:checkhealth mason` / `nvim-treesitter` check,
-- and warns when a Mason package on the host is not the version pinned in custom/tools.lua (`drift()`).
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

--- Mason writes the installed package's source id to its receipt; it always ends `@<version>`, and that suffix is the
--- pin (`pkg:npm/pyright@1.1.414`, `pkg:generic/Kotlin/kotlin-lsp@kotlin-lsp/v263.7084.0`).
---@param id string|nil
---@return string|nil
local function source_version(id) return id and id:match '@([^@]+)$' end

--- Source id from Mason's receipt, or nil when the package is not installed.
---@param name string
---@return string|nil
local function receipt_source_id(name)
  local path = vim.fs.joinpath(vim.fn.stdpath 'data', 'mason', 'packages', name, 'mason-receipt.json')
  if vim.fn.filereadable(path) == 0 then return nil end
  local ok, receipt = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), '\n'))
  return ok and receipt.source and receipt.source.id or nil
end

---@class custom.Drift
---@field name string
---@field pinned string
---@field installed string|nil nil when not installed

---@class custom.DriftEnv
---@field tools? { [1]: string, version: string }[] defaults to custom.tools' Mason list
---@field installed? fun(name: string): string|nil source id; defaults to Mason's receipt

--- Pinned Mason packages whose installed version differs from the pin (or that are not installed). `env` replaces
--- the lookups in tests.
---@param env? custom.DriftEnv
---@return custom.Drift[]
function M.drift(env)
  env = env or {}
  local tools = env.tools or require('custom.tools').mason
  local installed = env.installed or receipt_source_id
  local drift = {}
  for _, tool in ipairs(tools) do
    local have = source_version(installed(tool[1]))
    if have ~= tool.version then table.insert(drift, { name = tool[1], pinned = tool.version, installed = have }) end
  end
  return drift
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

  vim.health.start 'Mason packages'
  local drifted = {}
  for _, d in ipairs(M.drift()) do
    drifted[d.name] = d
  end
  for _, tool in ipairs(require('custom.tools').mason) do
    local d = drifted[tool[1]]
    if d then
      local state = d.installed and ('installed %s'):format(d.installed) or 'not installed'
      vim.health.warn(('%s: %s, pinned %s'):format(d.name, state, d.pinned), {
        ('Install the pin: `:MasonInstall %s@%s`'):format(d.name, d.pinned),
      })
    else
      vim.health.ok(('%s: at pin %s'):format(tool[1], tool.version))
    end
  end
end

return M
