-- Workspace symbol picker shared by `gW` (all symbols) and `gC` (Go to Class, custom/go_to_class.lua).
--
-- Telescope's dynamic workspace symbols sends the whole prompt to the server on every keystroke, including the
-- empty prompt on open. An empty `workspace/symbol` query makes jdtls return every symbol of the workspace and
-- of the JDK and libraries: seconds of server time and Lua work each time the picker opens. Here an empty prompt
-- sends nothing, and only one word goes to the server (see `query`); the whole prompt then fuzzy-filters the
-- results, whose ordinal includes the file path / jdt:// URI and so the package.
-- Tests: tests/test_workspace_symbols.lua; replayed on jdtls in tests/test_replay_gradle_java.lua. Items use utf-16
-- positions, like every feature of the config (jdtls and kotlin-lsp both use it).
--
-- Queries under 3 characters are not sent either: kotlin-lsp answers `S` with 10,687 symbols in 13.6s and `Sc`
-- with 4,602 in 5.1s (measured on agentic-marketplace-api; `Sco` takes 0.5s, `Scout` 15ms). The picker sends one
-- request per keystroke and waits for each, so the first two keystrokes of a name stalled the whole picker.
-- Known limit: nothing is listed until 3 characters of the name are typed.

local M = {}

-- Shortest word sent to the server; shorter ones match too many symbols to be slow to answer.
local MIN_QUERY = 3

--- The word sent to the server for a prompt: the first containing an uppercase letter, else the last word.
--- nil when that word is shorter than MIN_QUERY (or the prompt is blank), so no request is sent.
---@param prompt string
---@return string?
function M.query(prompt)
  local words = vim.split(prompt, '%s+', { trimempty = true })
  if #words == 0 then return nil end
  local query = words[#words]
  for _, word in ipairs(words) do
    if word:match '%u' then
      query = word
      break
    end
  end
  if #query < MIN_QUERY then return nil end
  return query
end

--- A picker or menu title saying what to type: the name of the picker and the minimum query length.
---@param name string
---@return string
function M.title(name) return ('%s (type %d+ characters)'):format(name, MIN_QUERY) end

--- Asks the servers of `bufnr` for the workspace symbols matching `query` and calls back with them as quickfix items
--- (text `[Kind] name`, filename, lnum, col). Returns a function cancelling the request.
---@param bufnr integer
---@param query string
---@param callback fun(items: table[])
---@return fun()
function M.symbols(bufnr, query, callback)
  return require('custom.implementations').request_all(
    'workspace/symbol',
    { query = query },
    function(symbols) callback(vim.lsp.util.symbols_to_items(symbols, bufnr, 'utf-16')) end,
    bufnr
  )
end

--- Width of the symbol name column for `items` (quickfix items, text `[Kind] name`): the longest name, between 25
--- columns and 40% of `columns`, as for `gO` (lua/custom/document_symbols.lua).
---@param items table[]
---@param columns? integer width of the editor in columns, vim.o.columns by default
---@return integer
function M.symbol_width(items, columns)
  local names = {}
  for _, item in ipairs(items) do
    table.insert(names, item.text:match '%[.-%]%s+(.*)' or item.text)
  end
  return require('custom.document_symbols').symbol_width(names, columns or vim.o.columns)
end

---@param opts? table telescope picker options, plus `symbols` (kinds to keep, as for builtin.lsp_*_symbols)
---@param prompt_title string
function M.picker(opts, prompt_title)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local channel = require('plenary.async.control').channel
  local conf = require('telescope.config').values
  local cancel = function() end
  local entry_maker
  local make_entry = function(entry) return entry_maker(entry) end
  require('telescope.pickers')
    .new(opts, {
      prompt_title = prompt_title,
      finder = require('telescope.finders').new_dynamic {
        entry_maker = make_entry,
        fn = function(prompt)
          local query = M.query(prompt)
          if not query then return {} end
          local tx, rx = channel.oneshot()
          cancel()
          cancel = M.symbols(bufnr, query, tx)
          local results = require('telescope.utils').filter_symbols(rx(), opts) or {}
          -- The name column is sized to these results, so the entry maker is rebuilt for each query before its entries are made.
          local sized = vim.tbl_extend('force', opts, { symbol_width = M.symbol_width(results) })
          entry_maker = require('telescope.make_entry').gen_from_lsp_symbols(sized)
          return results
        end,
      },
      sorter = conf.generic_sorter(opts),
      previewer = conf.qflist_previewer(opts),
    })
    :find()
end

return M
