# Export refactor code action title matching

Type: task
Status: open
Blocked by: 02

## What

- `refactor.title_matches(title, words)` (case-insensitive, plain substring), used by `code_action`.
- Smoke: in a buffer with a fake LSP client attached, `<leader>rn/ro/rv/rV/rc/rm` exist with `Refactor: ` desc;
  a handler registered via `register(bufnr, …)` overrides the default.

## Acceptance

Unit tests for match/no-match/case; smoke tests for map presence and override dispatch (visual flag passed).
