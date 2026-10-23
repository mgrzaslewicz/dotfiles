# stylua + lua-language-server checks, `mise run check`

Type: task
Status: resolved
Blocked by: 01, 02

## What

Spec decision 9; slice 1 item 9.

- Committed `.luarc.json`: nvim runtime + plugin dirs (from `tests/.tests/`) as workspace library, `vim` global.
- `mise run check` = `stylua --check dot_config/nvim` → `lua-language-server --check dot_config/nvim` → `mise run test`.
- Fix existing warnings; baseline only what can't be fixed (document each in `.luarc.json` with a reason).

## Acceptance

- `mise run check` passes on the current tree.
- Introducing an undefined global or a misformatted line makes it fail with a clear message.

## Notes

- stylua respects `.gitignore`, so `tests/.tests/` is skipped without a `.styluaignore`.
- `.luarc.json` takes plugin types from `tests/.tests/data/.../pack/core/opt` (same revisions as the lockfile)
  and ignores the other `tests/.tests/` dirs (the config symlink would recurse). `check:types` therefore needs
  one `mise run test` first; `check` runs format → test → types for that reason.
- `.luarc.json` is chezmoi-ignored: in `~/.config/nvim` the `lua_ls` `on_init` in `init.lua` sets the library itself.
- `$VIMRUNTIME` in `.luarc.json` is resolved from the environment; `check:types` sets it from the pinned nvim.
- Existing problems: stylua reformatted 5 files (mechanical); 3 `missing-fields` warnings on plugin setup
  tables suppressed with `---@diagnostic disable-next-line: missing-fields` (existing idiom in `debug.lua`).
- Timing: `check:types` ~16 s (scans ~3500 plugin files); full `check` ~18 s.
