# stylua + lua-language-server checks, `mise run check`

Type: task
Status: open
Blocked by: 01, 02

## What

Spec decision 9; slice 1 item 9.

- Committed `.luarc.json`: nvim runtime + plugin dirs (from `tests/.tests/`) as workspace library, `vim` global.
- `mise run check` = `stylua --check dot_config/nvim` → `lua-language-server --check dot_config/nvim` → `mise run test`.
- Fix existing warnings; baseline only what can't be fixed (document each in `.luarc.json` with a reason).

## Acceptance

- `mise run check` passes on the current tree.
- Introducing an undefined global or a misformatted line makes it fail with a clear message.
