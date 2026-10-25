# Layer B: refactor maps against real servers

Type: task
Status: resolved
Blocked by: 16

## What

Spec decision 19 row 3.

- `<leader>rv` (normal and visual) and `<leader>rm` (visual) on prepared code: jdtls via nvim-jdtls
  handlers (gradle-java), kotlin_lsp via code action titles (gradle-kotlin). Assert the buffer text after.
- Title words in `refactor.lua` adjusted test-first if kotlin_lsp titles differ.

## Acceptance

Both servers green, or a missing kotlin_lsp action asserted as a known limit.

## Notes

- Bug, found by the e2e probe: visual `<leader>rv`/`<leader>rm` with jdtls used a stale selection (or failed with
  "Error getting refactoring edit: Internal error"). The map called the handler while still in visual mode, so
  the '< and '> marks nvim-jdtls reads were from an earlier selection. `custom/refactor.lua` now leaves visual
  mode first and passes the marks as the range to the default code action (layer A `test_refactor.lua`).
- jdtls in normal mode asks which expression to extract (picker); the case answers it.
- kotlin_lsp titles ("Extract to local variable") match the existing title words; no change needed.
- Known limit: kotlin_lsp has no extract function; `<leader>rm` says "No code actions available".
