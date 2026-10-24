-- `:checkhealth custom`: checks for this config that no plugin covers.
--
-- The host nvim is installed independently of this repo (its mise.toml is not deployed), so the config records the
-- version the tests ran on and warns here, not at startup, when the running nvim differs.
-- Tests: tests/test_health.lua (also keeps `tested_version` equal to the repo's mise.toml pin).

local M = {}

M.tested_version = '0.12.6'

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
end

return M
