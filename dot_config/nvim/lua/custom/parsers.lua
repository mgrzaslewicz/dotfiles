-- Treesitter parsers from custom/tools.lua, kept installed. nvim-treesitter's install() skips a language whose queries
-- are linked, even when its parser was never built, and update() needs a revision file that such a parser lacks. So the
-- parsers whose compiled file is missing are installed with force; the rest are left alone.

local M = {}

--- Wanted parsers that are not built yet, in the order given.
---@param wanted string[]
---@param built string[]
---@return string[]
function M.missing(wanted, built)
  local have = {}
  for _, name in ipairs(built) do
    have[name] = true
  end
  return vim.tbl_filter(function(name) return not have[name] end, wanted)
end

--- Starts the install of the missing ones. Returns the task, or nil when nothing is missing.
---@param wanted string[]
---@return table|nil
function M.ensure(wanted)
  local ts = require 'nvim-treesitter'
  local missing = M.missing(wanted, ts.get_installed 'parsers')
  if #missing == 0 then return nil end
  return ts.install(missing, { force = true })
end

return M
