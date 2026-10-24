---
name: nvim-config
description: Work on the Neovim config in dot_config/nvim (the user's IntelliJ-replacement PDE for Java/Kotlin). Use for any change to it — new feature, keymap, plugin, fix, plugin update, cosmetics — and for running or writing its tests. Changes are test-first.
---

# Neovim config (`dot_config/nvim/`)

The config is a software project: its features are specified by tests in `dot_config/nvim/tests/`. Goal and
skill list: `dot_config/nvim/INTELLIJ_TRANSITION.md`.

## Commands (from the repo root)

| Command | What |
|---|---|
| `mise run test` | all tests (~5 s); `mise run test -- tests/test_x.lua` for one file (path relative to `dot_config/nvim`) |
| `mise run check` | everything a commit must pass: `stylua --check`, tests, lua-language-server diagnostics (~20 s) |
| `mise run setup` | once per clone: repo-local `core.hooksPath=.githooks` |

`stylua .` in `dot_config/nvim` fixes formatting. The pre-commit hook runs `mise run check` on commits touching
`dot_config/nvim/`, against the staged content only. Never `--no-verify` without the user saying so; when the hook
is not installed, run `mise run check` yourself before committing.

## Test-first, always

Every change to behaviour — features, fixes, keymaps, cosmetics such as a highlight group's color — follows:

1. Write or extend a test; run it and **see it fail** for the right reason (not a typo or missing helper).
2. Make the change.
3. `mise run check` green.

When a test passes before the change (guarding behaviour that already exists, e.g. before a refactor or deletion),
prove it bites: break the code on purpose, see the test fail, restore. Exploration happens in throwaway spikes,
never committed as-is; kept work is rebuilt test-first. Features without tests yet get a test when next touched
(list in `INTELLIJ_TRANSITION.md`).

## Test layout

- `tests/test_*.lua` — mini.test files, each returns a `MiniTest.new_set()`.
- Two kinds of test:
  - **Unit**: pure modules (`lua/custom/jvm/*.lua` and similar), required directly in the runner process.
    Logic belongs in such modules — no side effects on `require`, no `vim.fn.input`, inputs as arguments; plugin
    files stay thin wiring.
  - **Smoke**: the full config in a child nvim, `local child = require('tests.helpers').new_child()`, then
    `child.start()` per case and `child.stop()` after. `child.lua`, `child.lua_get`, `child.cmd`, `child.type_keys`
    drive it. `child.start { '--cmd', 'lua …' }` runs code before `init.lua` (fault injection, recording).
- `tests/helpers.lua`: `new_child()`, `tree(files)` (temp dir fixture, `'dir/'` for empty dirs),
  `attach_fake_lsp(child)` (fake server in the current buffer; offers code actions titled `_G.offered`, records
  applied ones in `_G.applied`).
- In a `child.lua [[ … ]]` chunk, `]]` inside the code ends the string early — use `[=[ … ]=]`.

## Environment

- `tests/run.sh` isolates everything in `tests/.tests/` (gitignored): XDG dirs, plugins, state. Config comes from
  the source tree, no `chezmoi apply` needed. First run installs plugins at `nvim-pack-lock.json` revisions;
  delete `tests/.tests` to start over.
- `NVIM_TEST=1` (set by `run.sh`, read as `vim.g.test_mode` in `init.lua`): skips Mason tool installs and
  treesitter parser installs. Plugins load; LSP servers are declared but never start (no JDK, no servers).
  Real-server tests (layer B) are not built yet.
- Versions are pinned in the repo `mise.toml` (neovim, stylua, lua-language-server). `lua/custom/health.lua`
  `tested_version` must equal the neovim pin (a test enforces it); `:checkhealth custom` warns on the host when
  they differ.
- Plugin update: `:lua vim.pack.update()` in daily nvim, `chezmoi re-add ~/.config/nvim/nvim-pack-lock.json`,
  `mise run check` (reinstalls test plugins at the new revisions only after `rm -rf tests/.tests`), commit the lockfile.

## Config conventions

- chezmoi: source in `dot_config/nvim/`, deployed to `~/.config/nvim/`. Edit the source; the user runs
  `chezmoi apply`. `tests/`, `.luarc.json` and the repo `mise.toml` are not deployed (`.chezmoiignore`).
- kickstart.nvim based: single `init.lua`, plus `lua/custom/plugins/*.lua` (explicitly `require`d at the bottom of
  `init.lua`) and `lua/kickstart/plugins/*.lua` (enabled by uncommenting the `require`).
- Plugins via built-in `vim.pack.add` (not lazy.nvim); build steps in the `PackChanged` autocmd in `init.lua`.
- LSP servers: the `servers` table in `init.lua`, installed via Mason (`jdtls` through nvim-jdtls, `kotlin_lsp`, `lua_ls`).
- Highlights (IntelliJ-like colors): `lua/custom/highlights.lua`; colorscheme `tokyonight-night`.
- Leader is `<Space>`. `<leader>` groups and desc prefixes live in the registry in `tests/test_keymaps.lua`
  (`u` test, `h` hunk, `g` git, `s` search, `t` toggle, `r` refactor, `d` debug, `b` build, `w` sessions). A new
  map of three or more keys goes in a group with its prefix; a new group starts in that registry. The test also
  rejects maps set twice or buffer maps shadowing global ones.
- Keymaps are language-agnostic: one key per action for all languages. Language-specific behaviour goes behind
  the shared key (e.g. `require('custom.refactor').register(bufnr, handlers)` for `<leader>r`), never a
  per-language prefix.
- Rationale and known limits go in the header comment of the feature's Lua file, not in separate docs.
