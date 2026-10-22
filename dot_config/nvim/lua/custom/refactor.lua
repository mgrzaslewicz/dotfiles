-- Language-agnostic refactor keymaps under <leader>r, set for every buffer with an LSP attached.
--
-- By default each action runs the matching LSP code action, so it works with any server that
-- offers it (kotlin_lsp, rust-analyzer, ...). A language whose plugin has a better implementation
-- registers it per buffer with `register` instead of adding its own keymaps (see custom/plugins/jdtls.lua).

local M = {}

---@param kind string LSP code action kind
---@param title_words? string[] keep only actions whose title contains one of these words
local function code_action(kind, title_words)
  return function()
    vim.lsp.buf.code_action {
      context = { only = { kind } },
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
  { name = 'extract_method', key = 'm', desc = 'Extract [M]ethod', mode = 'x', default = code_action('refactor.extract', { 'method', 'function' }) },
}

---@type table<integer, table<string, fun(visual: boolean)>>
local overrides = {}

--- Use language-specific implementations in a buffer, keyed by action name
--- (rename, organize_imports, extract_variable, extract_variable_all, extract_constant, extract_method).
--- Each receives `visual = true` when called from visual mode.
---@param bufnr integer
---@param handlers table<string, fun(visual: boolean)>
function M.register(bufnr, handlers)
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  overrides[bufnr] = handlers
end

-- Rename lives at <leader>rn; drop Neovim's built-in `grn` default so there is one key for it.
pcall(vim.keymap.del, 'n', 'grn')

local group = vim.api.nvim_create_augroup('custom-refactor', { clear = true })

vim.api.nvim_create_autocmd('LspAttach', {
  group = group,
  callback = function(event)
    for _, action in ipairs(actions) do
      vim.keymap.set(action.mode, '<leader>r' .. action.key, function()
        local visual = vim.fn.mode():match '^[vV\22]' ~= nil
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
