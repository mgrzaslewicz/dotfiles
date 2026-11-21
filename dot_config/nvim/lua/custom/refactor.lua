-- Language-agnostic refactor keymaps under <leader>r, set for every buffer with an LSP attached.
--
-- By default each action runs the matching LSP code action, so it works with any server that
-- offers it (kotlin_lsp, rust-analyzer, ...). A language whose plugin has a better implementation
-- registers it per buffer with `register` instead of adding its own keymaps (see custom/plugins/jdtls.lua).
-- If a server titles its extract actions differently, adjust the title words below or register a handler.
-- kotlin_lsp offers fewer refactorings than IntelliJ; large Kotlin refactors are still IntelliJ's job.
-- `<M-m>n` (rename_method) and `<M-m>S` (change_method_signature) run <leader>rn and <leader>rs on the name of the
-- method around the cursor, from anywhere in its body.
-- Known limit: kotlin_lsp offers no change signature, so <leader>rs and <M-m>S say "No code actions available" in Kotlin.
-- Known limit: kotlin_lsp has no extract function, so <leader>rm says "No code actions available" in Kotlin.

local M = {}

---@param kind string LSP code action kind
---@param title_words? string[] keep only actions whose title contains one of these words
local function code_action(kind, title_words)
  return function(visual)
    vim.lsp.buf.code_action {
      context = { only = { kind } },
      range = visual and { start = vim.api.nvim_buf_get_mark(0, '<'), ['end'] = vim.api.nvim_buf_get_mark(0, '>') } or nil,
      filter = title_words and function(action)
        local title = action.title:lower()
        for _, word in ipairs(title_words) do
          if title:find(word, 1, true) then return true end
        end
        return false
      end,
      apply = true,
    }
  end
end

local actions = {
  { name = 'rename', key = 'n', desc = 'Re[n]ame', mode = 'n', default = function() vim.lsp.buf.rename() end },
  { name = 'organize_imports', key = 'o', desc = '[O]rganize imports', mode = 'n', default = code_action 'source.organizeImports' },
  { name = 'extract_variable', key = 'v', desc = 'Extract [V]ariable', mode = { 'n', 'x' }, default = code_action('refactor.extract', { 'variable' }) },
  {
    name = 'extract_variable_all',
    key = 'V',
    desc = 'Extract [V]ariable (all occurrences)',
    mode = 'n',
    default = code_action('refactor.extract', { 'all occurrences' }),
  },
  { name = 'extract_constant', key = 'c', desc = 'Extract [C]onstant', mode = { 'n', 'x' }, default = code_action('refactor.extract', { 'constant' }) },
  -- jdtls offers it as a refactor code action whose command nvim-jdtls answers with a signature prompt.
  { name = 'change_signature', key = 's', desc = 'Change [S]ignature', mode = 'n', default = code_action('refactor', { 'signature' }) },
  { name = 'extract_method', key = 'm', desc = 'Extract [M]ethod', mode = 'x', default = code_action('refactor.extract', { 'method', 'function' }) },
}

---@type table<integer, table<string, fun(visual: boolean)>>
local overrides = {}

--- Use language-specific implementations in a buffer, keyed by action name
--- (rename, organize_imports, extract_variable, extract_variable_all, extract_constant, change_signature, extract_method).
--- Each receives `visual = true` when called from visual mode.
---@param bufnr integer
---@param handlers table<string, fun(visual: boolean)>
function M.register(bufnr, handlers)
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  overrides[bufnr] = handlers
end

--- Runs the refactor action `name` in the current buffer: the language's registered handler, else the default.
---@param name string
---@param visual? boolean
function M.run(name, visual)
  for _, action in ipairs(actions) do
    if action.name == name then return ((overrides[vim.api.nvim_get_current_buf()] or {})[name] or action.default)(visual or false) end
  end
  error('no refactor action ' .. name)
end

--- Runs the refactor action `name` on the name of the method around the cursor, from anywhere in its body: moves the
--- cursor there, with a jumplist entry (<C-o> goes back). The cursor stays on the name: the actions ask for input
--- asynchronously.
---@param name string
local function on_method_name(name)
  require('custom.implementations').method_around_cursor(function(here)
    vim.cmd "normal! m'"
    local line = vim.api.nvim_buf_get_lines(0, here.range.start.line, here.range.start.line + 1, false)[1] or ''
    local col = vim.str_byteindex(line, 'utf-16', here.range.start.character, false)
    vim.api.nvim_win_set_cursor(0, { here.range.start.line + 1, col })
    M.run(name)
  end)
end

--- Renames the method around the cursor (`<M-m>n`, IntelliJ Shift+F6 on it): <leader>rn on its name.
function M.rename_method() on_method_name 'rename' end

--- Changes the signature of the method around the cursor (`<M-m>S`, IntelliJ Ctrl+F6): <leader>rs on its name.
function M.change_method_signature() on_method_name 'change_signature' end

-- Rename lives at <leader>rn; drop Neovim's built-in `grn` default so there is one key for it.
pcall(vim.keymap.del, 'n', 'grn')

local group = vim.api.nvim_create_augroup('custom-refactor', { clear = true })

vim.api.nvim_create_autocmd('LspAttach', {
  group = group,
  callback = function(event)
    for _, action in ipairs(actions) do
      vim.keymap.set(action.mode, '<leader>r' .. action.key, function()
        local visual = vim.fn.mode():match '^[vV\22]' ~= nil
        -- Leave visual mode first: only then are the '< and '> marks set, and nvim-jdtls reads the selection
        -- from them (a stale, earlier selection otherwise).
        if visual then vim.cmd 'normal! \27' end
        local handler = (overrides[event.buf] or {})[action.name] or action.default
        handler(visual)
      end, { buffer = event.buf, desc = 'Refactor: ' .. action.desc })
    end
  end,
})

vim.api.nvim_create_autocmd('BufWipeout', {
  group = group,
  callback = function(event) overrides[event.buf] = nil end,
})

return M
