-- `<leader>/`: fuzzy search in the current buffer, in a Telescope dropdown. The stock dropdown caps its width at 80
-- columns, so on a wide window the prompt and results stayed narrow. Here the dialog takes 80% of the window width,
-- at most 200 columns.
-- Tests: tests/test_current_buffer_search.lua.

local M = {}

local SHARE = 0.8
local MAX_WIDTH = 200

--- Width of the dialog in columns: 80% of the window, at most 200.
---@param columns integer width of the editor in columns
---@return integer
function M.width(columns) return math.min(math.floor(columns * SHARE), MAX_WIDTH) end

--- Opens the fuzzy search over the current buffer, sized to the window.
function M.open()
  require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
    winblend = 10,
    previewer = false,
    layout_config = {
      width = function(_, max_columns) return M.width(max_columns) end,
    },
  })
end

return M
