-- Imports the types of pasted Java and Kotlin code, like IntelliJ does on paste.
--
-- After `p` or `P` in a buffer of jdtls or kotlin_lsp, the lines just put are checked by the server: each type it
-- cannot resolve gets its import quick fix. A type with one candidate is imported at once; several candidates (for
-- example kotlin.time.Duration and java.time.Duration) ask which package to use. Types that already resolve are left
-- alone, so nothing else is touched.
--
-- The server publishes diagnostics a moment after a change, so the hook waits for the put lines' diagnostics before
-- asking (`wait_ms` at most; a paste with no unresolved type never gets a request). Import titles differ by server:
-- jdtls "Import 'List' (java.util)", kotlin_lsp "Import class 'Duration' → kotlin.time.Duration".
--
-- Known limits: only normal-mode `p`/`P` trigger it, not insert-mode paste (Cmd+V in the terminal). The import
-- comes a moment after the paste, asynchronously.

local M = {}

--- Servers whose buffers get the hook (their import quick fixes are the ones it applies).
local SERVERS = { jdtls = true, kotlin_lsp = true }

--- How long to wait for the server's diagnostics of the put lines, in milliseconds.
M.wait_ms = 30000

---@param title string code action title, e.g. "Import 'List' (java.util)" or "Import class 'Duration' → kotlin.time.Duration"
---@return string? name the type name the import is for, nil when the title is not an import
function M.import_name(title) return title:match "^Import .-'([^']+)'" end

---@param actions table[] code actions the server offered
---@return { name: string, actions: table[] }[] import actions grouped by type name, names sorted
function M.group(actions)
  local by_name, names = {}, {}
  for _, action in ipairs(actions) do
    local name = M.import_name(action.title)
    if name then
      if not by_name[name] then
        by_name[name] = {}
        table.insert(names, name)
      end
      table.insert(by_name[name], action)
    end
  end
  table.sort(names)
  return vim.tbl_map(function(name) return { name = name, actions = by_name[name] } end, names)
end

--- Runs one code action: its edit, then its command. Resolves it first when the server needs that.
---@param client vim.lsp.Client
---@param bufnr integer
---@param action table
---@param done fun()
local function apply(client, bufnr, action, done)
  local function run(resolved)
    if resolved.edit then vim.lsp.util.apply_workspace_edit(resolved.edit, client.offset_encoding) end
    if resolved.command then client:exec_cmd(resolved.command, { bufnr = bufnr }) end
    done()
  end
  if action.edit or action.command or not client:supports_method 'codeAction/resolve' then return run(action) end
  client:request('codeAction/resolve', action, function(err, resolved) run(err and action or resolved) end, bufnr)
end

--- Imports the groups one after another: a single candidate is applied, several are chosen from.
---@param client vim.lsp.Client
---@param bufnr integer
---@param groups { name: string, actions: table[] }[]
local function import_each(client, bufnr, groups)
  local group = table.remove(groups, 1)
  if not group then return end
  local function next_group() import_each(client, bufnr, groups) end
  if #group.actions == 1 then return apply(client, bufnr, group.actions[1], next_group) end
  local titles = vim.tbl_map(function(action) return action.title end, group.actions)
  vim.ui.select(titles, { prompt = ('Import %s from'):format(group.name) }, function(choice)
    for _, action in ipairs(group.actions) do
      if action.title == choice then return apply(client, bufnr, action, next_group) end
    end
    next_group()
  end)
end

--- Calls `fn` with the diagnostics on lines `first` (0-based, inclusive) to `last` (exclusive) once the server has
--- published some, or does nothing after `wait_ms`.
---@param bufnr integer
---@param first integer
---@param last integer
---@param fn fun(diagnostics: table[])
local function when_diagnosed(bufnr, first, last, fn)
  local function in_range()
    return vim.tbl_filter(function(d) return d.lnum >= first and d.lnum < last end, vim.diagnostic.get(bufnr))
  end
  local finished, autocmd
  local function finish(diagnostics)
    if finished then return end
    finished = true
    pcall(vim.api.nvim_del_autocmd, autocmd)
    if diagnostics then fn(diagnostics) end
  end
  autocmd = vim.api.nvim_create_autocmd('DiagnosticChanged', {
    buffer = bufnr,
    callback = function()
      local diagnostics = in_range()
      if #diagnostics > 0 then finish(diagnostics) end
    end,
  })
  vim.defer_fn(function() finish(nil) end, M.wait_ms)
  local current = in_range()
  if #current > 0 then finish(current) end
end

--- Asks the server for the import quick fixes of the lines `first` (0-based, inclusive) to `last` (0-based, exclusive).
---@param bufnr integer
---@param first integer
---@param last integer
local function import_lines(bufnr, first, last)
  local client
  for _, c in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    if SERVERS[c.name] then client = c end
  end
  if not client then return end
  when_diagnosed(bufnr, first, last, function(diagnostics)
    local params = {
      textDocument = { uri = vim.uri_from_bufnr(bufnr) },
      range = { start = { line = first, character = 0 }, ['end'] = { line = last, character = 0 } },
      context = { only = { 'quickfix' }, diagnostics = vim.lsp.diagnostic.from(diagnostics) },
    }
    client:request('textDocument/codeAction', params, function(err, actions)
      if err or not actions then return end
      import_each(client, bufnr, M.group(actions))
    end, bufnr)
  end)
end

--- Called right after `p` or `P` (see `attach`): the put lines are the range between the '[ and '] marks.
function M.after_put()
  local bufnr = vim.api.nvim_get_current_buf()
  local first = vim.api.nvim_buf_get_mark(bufnr, '[')[1]
  local last = vim.api.nvim_buf_get_mark(bufnr, ']')[1]
  import_lines(bufnr, first - 1, last)
end

--- Makes `p` and `P` in a buffer import the types of what they put. The map keeps the put itself: counts and
--- registers typed before the key still apply.
---@param bufnr integer
function M.attach(bufnr)
  for _, key in ipairs { 'p', 'P' } do
    vim.keymap.set('n', key, key .. '<Cmd>lua require("custom.jvm.paste_imports").after_put()<CR>', {
      buffer = bufnr,
      desc = 'Put and import the types of the put lines',
    })
  end
end

--- Attaches the hook to every buffer a jdtls or kotlin_lsp client attaches to. Called once from init.lua.
function M.setup()
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('custom-paste-imports', { clear = true }),
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and SERVERS[client.name] then M.attach(event.buf) end
    end,
  })
end

return M
