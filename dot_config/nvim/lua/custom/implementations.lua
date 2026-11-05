-- References of the symbol under the cursor together with the references of its implementations (`grR`).
-- An LSP's references of an interface member do not include the overriding methods, so the implementations are
-- asked for (textDocument/implementation) and their references are merged in. Language-agnostic: any server that
-- answers implementation requests works (jdtls, kotlin_lsp). Tests: tests/test_implementations.lua.
--
-- `gri` (goto_implementation) falls back to the definition when there is no implementation: a concrete class is its
-- own implementation, and the server answers no implementations for it.
--
-- Known limit: the overrides are found only where the server reports them as implementations; a call through a
-- variable of the interface type is a reference of the interface member, as before.

local M = {}

--- A Location or a LocationLink as a Location.
---@param loc table
---@return {uri: string, range: table}
local function normalize(loc) return { uri = loc.uri or loc.targetUri, range = loc.range or loc.targetSelectionRange } end

--- Merges location lists into one: duplicates (same file and start) dropped, sorted by file, then position.
---@param lists table[] lists of Location or LocationLink
---@return {uri: string, range: table}[]
function M.merge(lists)
  local seen, merged = {}, {}
  for _, list in ipairs(lists) do
    for _, raw in ipairs(list) do
      local loc = normalize(raw)
      local start = loc.range.start
      local key = ('%s:%d:%d'):format(loc.uri, start.line, start.character)
      if not seen[key] then
        seen[key] = true
        table.insert(merged, loc)
      end
    end
  end
  table.sort(merged, function(a, b)
    if a.uri ~= b.uri then return a.uri < b.uri end
    if a.range.start.line ~= b.range.start.line then return a.range.start.line < b.range.start.line end
    return a.range.start.character < b.range.start.character
  end)
  return merged
end

--- Sends `method` to every client of the current buffer and calls back once with all their results, flattened.
---@param method string
---@param params table
---@param callback fun(results: table[])
local function request_all(method, params, callback)
  vim.lsp.buf_request_all(0, method, params, function(responses)
    local results = {}
    for _, response in pairs(responses) do
      if response.result then vim.list_extend(results, vim.islist(response.result) and response.result or { response.result }) end
    end
    callback(results)
  end)
end

--- Calls `callback` with the references of the symbol under the cursor merged with the references of each of its
--- implementations, once every server has answered.
---@param callback fun(locations: {uri: string, range: table}[])
function M.collect(callback)
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  request_all('textDocument/implementation', params, function(implementations)
    local targets = { { textDocument = params.textDocument, position = params.position } }
    for _, raw in ipairs(implementations) do
      local impl = normalize(raw)
      table.insert(targets, { textDocument = { uri = impl.uri }, position = impl.range.start })
    end
    local pending, lists = #targets, {}
    for index, target in ipairs(targets) do
      target.context = { includeDeclaration = true }
      request_all('textDocument/references', target, function(locations)
        lists[index] = locations
        pending = pending - 1
        if pending == 0 then callback(M.merge(lists)) end
      end)
    end
  end)
end

--- Jumps to the implementations of the word under the cursor (`gri`). A symbol with none, such as a concrete class,
--- goes to its definition instead, so `gri` always lands somewhere. One result jumps directly; several open a picker.
function M.goto_implementation()
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  request_all('textDocument/implementation', params, function(implementations)
    local builtin = require 'telescope.builtin'
    if #implementations > 0 then
      builtin.lsp_implementations()
    else
      builtin.lsp_definitions()
    end
  end)
end

--- Shows the references of the word under the cursor, with those of its implementations, in a Telescope picker.
function M.references()
  local word = vim.fn.expand '<cword>'
  M.collect(function(locations)
    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    pickers
      .new({}, {
        prompt_title = ('References of %s, with implementations'):format(word),
        finder = finders.new_table {
          results = vim.lsp.util.locations_to_items(locations, 'utf-16'),
          entry_maker = require('telescope.make_entry').gen_from_quickfix {},
        },
        previewer = conf.qflist_previewer {},
        sorter = conf.generic_sorter {},
      })
      :find()
  end)
end

return M
