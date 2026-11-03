-- Test file of an implementation file and back, by the Gradle/Maven layout: `src/main/…/Foo.kt` ↔
-- `src/test/…/FooTest.kt` (same package path, same module). Pure: a path in, the counterpart path out.
-- Keymap `<leader>ut` in custom/plugins/neotest.lua. Tests: tests/test_test_pair.lua.

local M = {}

--- The counterpart of a Java or Kotlin file: its test file when it is in `src/main`, the implementation when it is
--- a `…Test` file in `src/test`. Nil for anything else, so the keymap can say so.
---@param path string absolute path
---@return string?
function M.counterpart(path)
  local dir, name, ext = path:match '^(.*)/([^/]+)%.(%a+)$'
  if not dir or (ext ~= 'java' and ext ~= 'kt') then return nil end
  local module, rest = dir:match '^(.*)/src/main(/.*)$'
  if module then return ('%s/src/test%s/%sTest.%s'):format(module, rest, name, ext) end
  module, rest = dir:match '^(.*)/src/test(/.*)$'
  if module then
    local base = name:match '^(.*)Test$'
    if base then return ('%s/src/main%s/%s.%s'):format(module, rest, base, ext) end
  end
  return nil
end

return M
