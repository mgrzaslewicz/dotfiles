-- Live grep with a file-glob input: `<leader>sG` opens a grep picker whose prompt holds one of two inputs, the search
-- pattern or a file glob such as `*.json`. <Tab> switches between them; the prompt prefix says which one is active.
-- The glob starts as `*.*`, so files without an extension are left out; change it to the extension you want. An empty
-- glob searches every file. Tests: tests/test_grep.lua.
--
-- Known limit: the glob input is a single glob (rg `--glob`), not a list.

local M = {}

local vimgrep = { 'rg', '--color=never', '--no-heading', '--with-filename', '--line-number', '--column', '--smart-case' }

local labels = { pattern = 'grep> ', glob = 'glob> ' }

--- The rg command for a search. The pattern follows `--`, so it is never read as a flag; `--glob` is added only for a
--- non-empty glob. Nil when there is no pattern, which means no search.
---@param pattern string
---@param glob string
---@param base string[]? arguments before the glob (defaults to the vimgrep ones)
---@return string[]?
function M.command(pattern, glob, base)
  if pattern == '' then return nil end
  local args = vim.list_extend({}, base or vimgrep)
  if glob ~= '' then vim.list_extend(args, { '--glob', glob }) end
  table.insert(args, '--')
  table.insert(args, pattern)
  return args
end

--- The input that <Tab> switches to.
---@param field 'pattern'|'glob'
---@return 'pattern'|'glob'
function M.other(field) return field == 'pattern' and 'glob' or 'pattern' end

--- Opens the grep picker. Both inputs are kept while the picker is open: the one not shown is stored and restored on
--- <Tab>.
---@param opts table? telescope options (cwd, ...)
function M.open(opts)
  opts = opts or {}
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local make_entry = require 'telescope.make_entry'
  local sorters = require 'telescope.sorters'
  local conf = require('telescope.config').values
  local action_state = require 'telescope.actions.state'

  local state = { focus = 'pattern', pattern = '', glob = '*.*' }

  -- The prompt holds the focused input, so its text is the field being typed. The other one is in `state`.
  local finder = finders.new_job(function(prompt)
    state[state.focus] = prompt
    return M.command(state.pattern, state.glob)
  end, make_entry.gen_from_vimgrep(opts), nil, opts.cwd)

  -- The text typed in the prompt, read from its buffer: telescope's current line can lag behind fast typing.
  local function prompt_text(picker)
    local line = vim.api.nvim_buf_get_lines(picker.prompt_bufnr, 0, 1, false)[1]
    return line:sub(#picker.prompt_prefix + 1)
  end

  local function switch(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)
    state[state.focus] = prompt_text(picker)
    state.focus = M.other(state.focus)
    picker:change_prompt_prefix(labels[state.focus], nil)
    picker:reset_prompt(state[state.focus])
  end

  pickers
    .new(opts, {
      prompt_title = 'Live Grep (pattern + glob)',
      prompt_prefix = labels.pattern,
      finder = finder,
      previewer = conf.grep_previewer(opts),
      sorter = sorters.empty(),
      attach_mappings = function(_, map)
        map({ 'i', 'n' }, '<Tab>', switch)
        return true
      end,
    })
    :find()
end

return M
