# Export refactor code action title matching

Type: task
Status: resolved
Blocked by: 02

## What

- `refactor.title_matches(title, words)` (case-insensitive, plain substring), used by `code_action`.
- Smoke: in a buffer with a fake LSP client attached, `<leader>rn/ro/rv/rV/rc/rm` exist with `Refactor: ` desc;
  a handler registered via `register(bufnr, …)` overrides the default.

## Acceptance

Unit tests for match/no-match/case; smoke tests for map presence and override dispatch (visual flag passed).

## Notes

- `title_matches` was not exported: `refactor.lua` has side effects on `require`, and the matching is better
  specified through the real path. `tests/test_refactor.lua` attaches a fake LSP server (`vim.lsp.start` with a
  function `cmd`) that offers code actions; each applies by running a client-side command that records its
  title, so the tests assert which action a key applies (case-insensitive match, "function" for extract method,
  all-occurrences vs single, nothing when no title matches).
- Smoke: buffer-local maps and descs per mode; a `register` handler overrides the default and gets the visual flag.
- Mutation checks: dropping `:lower()` fails 1 case; a filter accepting everything fails 4.
- Known: `<leader>rv` also matches "Extract variable (replace all occurrences)", so a server offering both shows a
  picker. Left as is.
