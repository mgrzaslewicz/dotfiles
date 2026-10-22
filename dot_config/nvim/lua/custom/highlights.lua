-- IntelliJ-style semantic highlighting, layered on top of the active colorscheme.
--
-- Simple cases map onto LSP semantic token groups (`:help lsp-semantic-highlight`)
-- and their treesitter fallbacks. Cases that need a combination of modifiers, or
-- must win over another modifier group, are applied from an LspTokenUpdate autocmd.
--
-- Use `:Inspect` on a symbol to see which groups apply to it.

local colors = {
  parameter = '#DED023',
  local_variable = '#FF48D2',
  interface = '#3F7FFF',
  function_declaration = '#FFC66D',
  constant = '#9876AA',
  reassigned_variable = '#707D95',
  abstract_method = '#22AF23',
  annotation = '#BBB529',
  abstract_class = '#2AFF23',
}

local groups = {
  -- Method parameter
  ['@lsp.type.parameter'] = { fg = colors.parameter },
  ['@variable.parameter'] = { fg = colors.parameter },

  -- Local variable
  ['@lsp.type.variable'] = { fg = colors.local_variable },
  ['@variable'] = { fg = colors.local_variable },

  -- Interface
  ['@lsp.type.interface'] = { fg = colors.interface },

  -- Function declaration (declaration site only, not calls)
  ['@lsp.typemod.function.declaration'] = { fg = colors.function_declaration },
  ['@lsp.typemod.method.declaration'] = { fg = colors.function_declaration },

  -- Constant
  ['@constant'] = { fg = colors.constant },
  ['@lsp.type.enumMember'] = { fg = colors.constant },

  -- Reassigned local variable (rust-analyzer: mutable, Kotlin LSP: modification)
  ['@lsp.typemod.variable.mutable'] = { fg = colors.reassigned_variable, underline = true },
  ['@lsp.typemod.variable.modification'] = { fg = colors.reassigned_variable, underline = true },
  ['@lsp.typemod.property.modification'] = { fg = colors.reassigned_variable, underline = true },

  -- Annotation type
  ['@lsp.type.annotation'] = { fg = colors.annotation },
  ['@lsp.type.decorator'] = { fg = colors.annotation },
  ['@attribute'] = { fg = colors.annotation },

  -- Groups used by the LspTokenUpdate autocmd below
  IntellijAnnotation = { fg = colors.annotation },
  IntellijConstant = { fg = colors.constant },
  IntellijAbstractMethod = { fg = colors.abstract_method },
  IntellijAbstractClass = { fg = colors.abstract_class },
}

local function apply()
  for group, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

-- Re-apply whenever a colorscheme is loaded, since it clears custom highlights.
vim.api.nvim_create_autocmd('ColorScheme', {
  group = vim.api.nvim_create_augroup('custom-intellij-highlights', { clear = true }),
  callback = apply,
})
apply()

-- Above the default priority of semantic token groups (125-127).
local priority = vim.hl.priorities.semantic_tokens + 5

-- Kotlin LSP reports annotation names as method/class tokens, hiding treesitter's @attribute.
local function is_annotation(buf, token)
  for _, capture in ipairs(vim.treesitter.get_captures_at_pos(buf, token.line, token.start_col)) do
    if capture.capture == 'attribute' then
      return true
    end
  end
  return false
end

vim.api.nvim_create_autocmd('LspTokenUpdate', {
  group = vim.api.nvim_create_augroup('custom-intellij-tokens', { clear = true }),
  callback = function(args)
    local token = args.data.token
    local mods = token.modifiers
    local hl

    if (token.type == 'method' or token.type == 'class') and is_annotation(args.buf, token) then
      hl = 'IntellijAnnotation'
    elseif (token.type == 'property' or token.type == 'variable') and mods.static and mods.readonly then
      -- Java `static final` fields, Kotlin `const val`
      hl = 'IntellijConstant'
    elseif token.type == 'method' and mods.abstract then
      hl = 'IntellijAbstractMethod'
    elseif token.type == 'class' and mods.abstract then
      hl = 'IntellijAbstractClass'
    end

    if hl then
      vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, hl, { priority = priority })
    end
  end,
})
