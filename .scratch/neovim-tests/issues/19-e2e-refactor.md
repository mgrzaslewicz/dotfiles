# Layer B: refactor maps against real servers

Type: task
Status: open
Blocked by: 16

## What

Spec decision 19 row 3.

- `<leader>rv` (normal and visual) and `<leader>rm` (visual) on prepared code: jdtls via nvim-jdtls
  handlers (gradle-java), kotlin_lsp via code action titles (gradle-kotlin). Assert the buffer text after.
- Title words in `refactor.lua` adjusted test-first if kotlin_lsp titles differ.

## Acceptance

Both servers green, or a missing kotlin_lsp action asserted as a known limit.
