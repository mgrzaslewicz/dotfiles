-- Rust conventions the config needs, used by Rust debug (custom/plugins/debug.lua).
-- Pure: file text in, answers out. Tests: tests/test_rust.lua.

local M = {}

--- Name of the package a Cargo.toml defines: the `name` in its `[package]` table, as cargo names the default binary.
--- Nil for a virtual workspace manifest, which has no `[package]`.
---@param cargo_toml string the manifest's text
---@return string|nil
function M.package_name(cargo_toml)
  local in_package = false
  for line in (cargo_toml .. '\n'):gmatch '(.-)\n' do
    local table_name = line:match '^%s*%[+(.-)%]+%s*$'
    if table_name then
      in_package = table_name == 'package'
    elseif in_package then
      local name = line:match '^%s*name%s*=%s*"([^"]+)"'
      if name then return name end
    end
  end
end

return M
