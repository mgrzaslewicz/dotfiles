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
| `mise run test:e2e` | layer B, real servers/builds/DAP (`tests/e2e/`); on demand, see below. `-- tests/e2e/test_x.lua` for one file |
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
- In a `child.lua [[ … ]]` chunk, `]]` inside the code ends the string early — use `[=[ … ]=]`. A syntax error
  in a test file is not a red test: check that the failure message is the one you expect.

## Layer B: end-to-end (`tests/e2e/`)

Real jdtls, kotlin-lsp, Gradle, Maven, neotest and DAP on fixture projects. Not part of `check` or the hook.

- **Run it** after `vim.pack.update()`, after bumping a Mason pin (`lua/custom/tools.lua`) or the JDK, and when
  changing LSP, DAP, test or task wiring. First run downloads ~1.7 GB into `tests/.tests-e2e/` (about a minute
  here); later runs reuse it.
- `tests/run.sh --e2e`: preflight (`tests/e2e/preflight.lua`, prerequisites from `custom/health.lua`), then
  `tests/e2e/bootstrap.lua` installs pinned Mason packages and parsers and fails if anything is not as pinned.
  No `NVIM_TEST`. Gradle/Maven caches live in the e2e root.
- Layout: one file per fixture (`tests/e2e/test_<fixture>.lua`), one child for the file (`pre_once`), cases in
  order and cleaning up after themselves; names `<fixture> | <feature> | <behaviour>`. Fixtures in
  `tests/e2e/fixtures/`, copied to a temp dir by `e2e.copy_fixture` — never built in place.
- `tests/e2e/helpers.lua`: `e2e.fixture_set(name)` (copy, one child, `ctx.child`/`ctx.project`), `e2e.wait(child,
  kind, what, condition)` — the runner polls `condition` (a Lua expression run in the child) until a deadline by
  kind (`attach`, `index`, `build`, `dap`) × `E2E_TIMEOUT_FACTOR`, then fails with a dump (clients and their
  diagnostics capabilities, `_G.e2e`, `:messages`, LSP log). Conditions must be cheap and never block: send LSP
  requests asynchronously and poll the result (see `definition_reaches`); a long `vim.wait` or
  `buf_request_sync` inside the child once hung a run for 30+ minutes. Also `expect_jdtls`, `expect_kotlin_lsp`,
  `clients`, `definition_reaches`, `errors`, `compile_errors` (`<leader>bc` with the picker answered),
  `neotest_run_file` (neotest discovers lazily: nothing is listed before the first run), `refactor` (cursor or
  selection on a text, keys, picker answer, buffer lines after). No retries, no sleeps.
- Cases that read `:messages` clear them first (`messages clear`): earlier cases in the same child leave some.
- Assert positive signals: "no errors" means nothing until something proves diagnostics arrived. Each fixture
  source carries a deliberate warning: an unused import for jdtls, an unnecessary `!!` on a Kotlin `String` for
  kotlin-lsp (which does not report unused variables).
- Debugging a stuck e2e child: it listens on a socket (`nvim --server <addr> --remote-expr 'luaeval(...)'`), and
  kotlin-lsp logs to `/tmp/idea-system*/system/log/intellij-server.log`. Throwaway probe test files can live in
  the scratchpad and run with `mise run test:e2e -- <absolute path>`.
- A gap found by an e2e test is asserted as a named known limit (also in the feature's Lua header); the fix is
  separate work. Manual checks, not automated: Shift+F8 delivery in terminals, dap-ui look, `git mergetool`
  conflict flow, Rust refactor titles.

## Environment

- `tests/run.sh` isolates everything in `tests/.tests/` (gitignored): XDG dirs, plugins, state. Config comes from
  the source tree, no `chezmoi apply` needed. First run installs plugins at `nvim-pack-lock.json` revisions;
  delete `tests/.tests` to start over. Layer A only collects `tests/test_*.lua` (not `tests/e2e/`).
- `NVIM_TEST=1` (set by `run.sh`, read as `vim.g.test_mode` in `init.lua`): skips Mason tool installs and
  treesitter parser installs. Plugins load; LSP servers are declared but never start (no JDK, no servers).
  Real servers are layer B.
- Versions are pinned: neovim, stylua, lua-language-server, and for e2e java (25: jdtls needs it), gradle, maven,
  tree-sitter in the repo `mise.toml`; Mason packages and the parser list in `lua/custom/tools.lua`. `lua/custom/health.lua`
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
