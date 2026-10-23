# Neovim PDE tests — PRD

Goal: treat the Neovim config (`dot_config/nvim/`) as a software project. Its
features — the IntelliJ replacements tracked in `INTELLIJ_TRANSITION.md` — are
specified and protected by automated tests, run locally and on every commit
that touches the config.

## Problem

- No tests exist. Regressions after `vim.pack.update()` or config edits are
  found by hand, in daily use.
- `[verify]` items in `INTELLIJ_TRANSITION.md` are manual acceptance checks.
- Testable logic is `local` inside plugin files that run side effects on
  `require` (`vim.pack.add`, `setup`), so nothing can reach it.
- Plugin versions are not pinned (`nvim-pack-lock.json` is gitignored); nvim is
  a snap that auto-refreshes. Same config, different results per machine/day.
- Duplicated logic already drifted: `tasks.lua` `find_project` and `debug.lua`
  `kotlin_project_root` use different marker lists and semantics.

## Decisions

### Strategy

1. Two layers.
   - **A — unit + smoke** (this PRD): pure-function tests and config wiring,
     headless, no JDK, no LSP servers.
   - **B — end-to-end** (deferred, separate grilling): real jdtls/kotlin_lsp on
     fixture Gradle/Maven projects, quickfix from real compiles, neotest, DAP.
2. Framework: `mini.test` (already shipped via mini.nvim). Child nvim per test
   (`MiniTest.new_child_neovim()`) for isolation.
3. Environment is isolated and pinned:
   - `XDG_DATA_HOME` / `XDG_STATE_HOME` / `XDG_CACHE_HOME` point at
     `dot_config/nvim/tests/.tests/` (gitignored).
   - `nvim-pack-lock.json` is committed (remove from `dot_config/nvim/.gitignore`).
     Plugin update flow: `vim.pack.update()` → `mise run check` → commit lockfile.
   - nvim pinned in repo `mise.toml` (`neovim@0.12.6`, latest offered at time of writing).
4. Daily nvim switches from snap to the mise-pinned nvim — tests vouch for the
   binary actually used. nvim bumps go through the same update → check → commit loop.
5. Tests live in `dot_config/nvim/tests/` (`test_*.lua`), excluded from
   deployment via `.chezmoiignore`. They load the **source tree**
   (`-u dot_config/nvim/init.lua`, rtp at source) — no `chezmoi apply` needed
   to test.

### Code shape

6. Logic moves into pure modules (no side effects on `require`, no
   `vim.fn.input`, inputs passed as arguments). Plugin files become thin wiring.
   Wiring is covered by the smoke suite.
7. Project detection, one module, two concepts (IntelliJ "project" vs "module"):
   - `project.root(dir)` — marker priority: `gradlew`/`mvnw` > `settings.gradle*`
     > `build.gradle*`/`pom.xml` (today's `tasks.lua` semantics). Returns
     `{ tool, root, cmd }`. Used by tasks.
   - `project.module(dir)` — nearest module dir (today's `kotlin_project_root`
     behaviour). Used by Kotlin debug.
   - Whether kotlin-debug-adapter needs the module or the root: layer B check.
8. Test profile `NVIM_TEST=1`: config skips mason-tool-installer and treesitter
   auto-installs. Plugins still load. LSP configs are declared, not attached.
   Layer B runs without it.

### Process

9. `mise run check` = `stylua --check` + `lua-language-server --check` + tests,
   all on `dot_config/nvim/`. Run locally; no CI.
   - stylua and lua-language-server pinned via mise.
   - `.luarc.json` committed (remove from `.gitignore`), pointing at the nvim
     runtime and plugin types so `--check` is meaningful.
10. Pre-commit hook `.githooks/pre-commit` (hand-rolled, tracked; chezmoi ignores
    dot-prefixed source paths):
    - exits 0 when `git diff --cached --name-only -- dot_config/nvim/` is empty;
    - otherwise runs `mise run check` against **staged** content
      (`git stash --keep-index --include-untracked`, restore on exit via trap);
    - installed by `mise run setup` → repo-local `git config core.hooksPath .githooks`
      (never global — `run_onchange_git_config.sh` sets global config). Worktrees
      share repo config, so one setup covers all worktrees.
11. Agent skill `.claude/skills/<name>/SKILL.md` documents: how to run tests, the
    test-first rule, `NVIM_TEST`, the hook and `mise run setup`, test layout and
    helpers, and the former "Notes for agents" from `INTELLIJ_TRANSITION.md`
    (chezmoi source vs deploy, `vim.pack`, mason servers, language-agnostic
    keymaps, prefix registry → see smoke test).
12. Test-first is mandatory for feature work: failing test → change → green
    `mise run check`. Cosmetics included (e.g. highlight group exists with
    expected fg). Exploration happens in throwaway spikes (prototype skill or
    scratch branch), never committed as-is; kept work is rebuilt test-first.

### Docs

13. Tests are the spec. `INTELLIJ_TRANSITION.md` shrinks to: goal summary,
    `[skill]` list, pointers to test files per feature, and a "no tests yet" list.
    `[setup]` / `[verify]` items leave the file.
14. Rationale and known limits move to header comments of the feature's Lua file
    (pattern already used in `debug.lua`, `refactor.lua`). Examples: codediff over
    diffview, no google-java-format, persistence over mini.sessions, Shift+F8
    terminal caveat, `<leader>ud` Java-only. The Log section is dropped (git history).
15. Keymap prefix registry becomes a smoke test: each `<leader>X` group maps to
    an expected desc prefix (`u` test, `h` hunk, `g` git, `s` search, `t` toggle,
    `r` refactor, `d` debug, `b` build, `w` sessions), and no duplicate lhs per mode.

## Slice 1 (this PRD's deliverable)

1. Pinned env: `mise.toml` (neovim, stylua, lua-language-server), un-ignore
   `nvim-pack-lock.json` and `.luarc.json`, `.chezmoiignore` entry for `tests/`.
2. Harness: `tests/minimal_init.lua` (XDG isolation, rtp at source, mini.test
   bootstrap), child-nvim helpers, `mise run test` / `check` / `setup` tasks.
3. `NVIM_TEST=1` profile in `init.lua`.
4. Smoke suite: startup with no errors/messages, keymap prefix registry,
   overseer template registered, quickfix populated from sample compiler
   output through the real errorformat.
5. Extract + unit test:
   - `project` (`root`, `module`) — fixtures in temp dirs: Gradle subproject,
     Maven submodule, wrapper-less builds, no project, nested `build/`/`target/`.
   - `errorformat` — javac, kotlinc (new and old format), Maven `[ERROR]`/`[WARNING]`,
     kotlin-maven-plugin `file://` paths; asserted via `vim.fn.getqflist` on `setqflist({lines=…, efm=…})`.
   - Spring Boot detection (`uses_spring_boot`).
   - Kotlin main class name from `(lines, filename)` (input prompt stays in wiring).
   - Refactor title matching (`title_matches(title, words)`).
6. Hook + `mise run setup`.
7. Skill.
8. Delete the snap libgomp workaround in `git.lua`.
9. Fix or baseline existing lua_ls `--check` warnings.
10. Rewrite `INTELLIJ_TRANSITION.md` per decision 13; move rationale per 14.

Out of slice 1: tests for remaining features (hierarchy maps, `go_to_class`,
jdtls wiring, `<leader>Q`, debug maps, git, sessions, highlights, neotest-java
Kotlin fix, mini.jump2d labels) — backfilled when next touched, listed as
"no tests yet" in the plan.

## Deferred

- Layer B design: fixture projects, JDK in the test env, Mason installs, which
  `[verify]` items become automated vs stay manual.
- kotlin-debug-adapter `projectRoot`: module vs root.

## Acceptance

- `mise run check` passes from a clean clone after `mise install` (first run
  bootstraps `.tests/`; later runs < 10 s for layer A target).
- Commit touching `dot_config/nvim/` with a failing test is rejected; commit
  touching only other paths does not run the check.
- Partially staged change is checked as staged, working tree restored afterwards.
- `chezmoi apply` deploys no test files, no `.tests/` state.
- Daily nvim (`which nvim`) is the mise-pinned version.
