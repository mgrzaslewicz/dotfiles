-- Kotlin compiler conventions the config needs to know, used by Kotlin debug (custom/plugins/debug.lua).
-- Pure: buffer lines and file names in, answers out. Tests: tests/test_kotlin.lua.

local M = {}

--- JVM class holding the top-level functions (e.g. `fun main`) of a Kotlin file: `<package>.<File>Kt`, with the
--- file name capitalized and invalid characters replaced as kotlinc does, or the `@file:JvmName` if present.
--- The package header must come before imports and code, so the first `package` line is it, however long the
--- license header above.
---@param lines string[] the file's lines
---@param filename string
---@return string
function M.main_class(lines, filename)
  local pkg, jvm_name
  for _, line in ipairs(lines) do
    jvm_name = jvm_name or line:match '^%s*@file:JvmName%("([^"]+)"%)'
    pkg = line:match '^%s*package%s+([%w_.]+)'
    if pkg then break end
  end
  local class = jvm_name or (vim.fn.fnamemodify(filename, ':t:r'):gsub('[^%w_$]', '_'):gsub('^%l', string.upper) .. 'Kt')
  return pkg and (pkg .. '.' .. class) or class
end

return M
