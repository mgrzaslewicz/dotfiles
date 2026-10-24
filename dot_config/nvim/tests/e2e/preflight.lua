-- Fails fast, before any download, when a program the e2e tests need is missing (list: custom/health.lua).
-- Run by tests/run.sh --e2e as `nvim --clean --headless -l tests/e2e/preflight.lua` from the config root.
package.path = './lua/?.lua;' .. package.path

local problems = require('custom.health').missing()
if #problems == 0 then return end
io.stderr:write 'e2e preflight: missing prerequisites\n'
for _, p in ipairs(problems) do
  io.stderr:write(('  %s\n    install: %s\n'):format(p.message, p.hint))
end
os.exit(1)
