# IntelliJ → Neovim transition plan

Tracks the switch from IntelliJ to Neovim as the daily IDE for Java/Kotlin work.
Two kinds of items: **[setup]** = config work an agent can do, **[skill]** = muscle memory the user practices.
Tick boxes (`- [x]`) as items are done and keep notes inline.

## Notes for agents

- This repo is managed by chezmoi: source lives in `~/dotfiles/dot_config/nvim/` (deployed to `~/.config/nvim/`).
  Edit the source, then the user runs `chezmoi apply`.
- Config is kickstart.nvim based, single `init.lua` plus `lua/custom/plugins/*.lua` (explicitly `require`d at the
  bottom of `init.lua`) and `lua/kickstart/plugins/*.lua` (enable by uncommenting the `require`).
- Plugins are installed with the built-in `vim.pack.add` (not lazy.nvim). Build steps go in the `PackChanged` autocmd in `init.lua`.
- LSP servers are declared in the `servers` table in `init.lua` and installed via mason (`jdtls`, `kotlin_lsp`, `lua_ls`).
- Custom highlights (IntelliJ-like colors) live in `lua/custom/highlights.lua`; colorscheme is `tokyonight-night`.
- Leader is `<Space>`. Test maps use `<leader>u`, git hunk maps `<leader>h`, git (repo-wide) `<leader>g`, search maps `<leader>s`,
  toggles `<leader>t`, refactor `<leader>r`, debug `<leader>d`, build/run tasks `<leader>b`, sessions `<leader>w`.
  Check `<leader>sk` / which-key for conflicts before adding maps.
- Keymaps are language-agnostic: one key per action for all languages. Add language-specific behaviour behind the
  shared keys (e.g. `require('custom.refactor').register` for `<leader>r`), never per-language prefixes.

## Already in place

- [x] File navigation, vim motions, mini.jump2d, Telescope file/grep search, LSP symbol search (`gO`, `gW`)
- [x] LSP: `grd` definition, `grr` references, `gri` implementation, `grt` type definition, `gra` code action, `K` hover
- [x] Completion (blink.cmp), inlay hints toggle (`<leader>th`)
- [x] Tests: neotest with neotest-java (Java) and neotest-gradle (Kotlin) — `<leader>ur/uf/ua/ul/ux/us/uo/uO`, `]u`/`[u`
- [x] Git hunks: gitsigns — `]c`/`[c`, `<leader>hs/hr/hp/hb/hd`
- [x] Text objects (mini.ai), surround (mini.surround), formatting (conform, `<leader>f`)
- [x] Project tree: neo-tree

## 1. Code intelligence

- [x] [setup] Call hierarchy (IntelliJ Ctrl+Alt+H): `grc` incoming, `grC` outgoing (Telescope pickers)
- [x] [setup] Type hierarchy (IntelliJ Ctrl+H): `grh` subtypes, `grH` supertypes (`vim.lsp.buf.typehierarchy`, results in quickfix)
- [ ] [skill] Use `grc`/`grC`/`grh`/`grH` instead of grepping for callers and implementors
- [x] [setup] nvim-jdtls replaces plain lspconfig `jdtls` (`lua/custom/plugins/jdtls.lua`): Lombok agent from Mason,
      per-project workspace dir in `stdpath('cache')/jdtls/`. Backs the shared `<leader>r` refactor maps (below).
      Debug bundles go in `init_options.bundles` (section 3). Client is still named `jdtls`, which neotest-java needs.
- [ ] [verify] Open a Java project: jdtls attaches (`:checkhealth vim.lsp`), Lombok getters resolve, `<leader>ua` still runs tests
- [x] [setup] Language-agnostic refactor maps (`lua/custom/refactor.lua`), any LSP buffer: `<leader>rn` rename (replaces `grn`), `<leader>ro` organize imports,
      `rv`/`rV` extract variable (all occurrences), `rc` extract constant, `rm` extract method (visual).
      Default = matching LSP code action; Java uses nvim-jdtls via `require('custom.refactor').register(bufnr, handlers)`.
- [ ] [verify] `<leader>r` maps in Kotlin and Rust; if a server titles its extract actions differently, adjust the
      title words in `refactor.lua` or register a handler for that language
- [ ] [skill] `<leader>r` refactors (IntelliJ Shift+F6, Ctrl+Alt+O / V / C / M)
- [ ] [skill] `<C-o>` / `<C-i>` jump back/forward (IntelliJ Ctrl+Alt+←/→)
- [ ] [skill] `gra` as Alt+Enter: imports, quick fixes, generate…
- [ ] [skill] Completion keys: `<C-space>`, `<C-y>` accept, `<C-k>` signature
- [ ] [note] `kotlin_lsp` has fewer refactorings than IntelliJ; fall back to IntelliJ for large Kotlin refactors

## 2. Diagnostics and quickfix

- [ ] [skill] `]d` / `[d` next/prev diagnostic, `<C-w>d` diagnostic float (IntelliJ F2 / Shift+F2)
- [x] [setup] `<leader>Q` project-wide errors to quickfix (`]d`/`[d` already open the diagnostic float on jump)
- [ ] [skill] `<leader>sd` workspace diagnostics, `<leader>q` buffer location list, `<leader>Q` project errors in quickfix
- [ ] [skill] Quickfix workflow: `:copen`, `]q` / `[q`, `:cdo` — grep results, test failures and build errors all land here

## 3. Build, run, debug

- [x] [setup] Task runner (`lua/custom/plugins/tasks.lua`): overseer.nvim with a Gradle/Maven provider. Project root is
      the nearest `gradlew`/`mvnw`, else settings/build file, so it works from subprojects. Tasks: gradle `classes`/`build`/
      `test`/`check`/`clean`/`run`, mvn `compile`/`package`/`test`/`verify`/`clean`/`install`, plus `bootRun`
      (and `bootRun --debug-jvm`) / `spring-boot:run` when a build file mentions Spring Boot, and `gradle …`/`mvn …` for any args.
      javac/kotlinc/Maven errors stream into quickfix (opens on failure). Maps: `<leader>bb` pick task, `bc` compile
      (IntelliJ Ctrl+F9), `bl` rerun last (Shift+F10), `bt` task list, `ba` task action (stop/restart/output), `bs` shell command.
- [ ] [verify] Gradle and Maven projects: task list shows up, a compile error lands in quickfix with the right file/line,
      `bootRun --debug-jvm` + `<leader>dc` "Attach" works. Kotlin error lines vary by KGP version; adjust `errorformat` in `tasks.lua`.
- [x] [setup] Debugger (`lua/custom/plugins/debug.lua`): nvim-dap + nvim-dap-ui (opens/closes with the session) +
      nvim-dap-virtual-text (inline values). Java adapter from nvim-jdtls with Mason's `java-debug-adapter` bundle;
      main classes are discovered on `<leader>dc`; hot code replace on save. Extra config: attach to JVM on localhost:5005.
      Language-agnostic maps under `<leader>d`: `db` breakpoint, `dB` conditional, `dL` log point, `dc` start/continue,
      `dl` run last, `dC` run to cursor, `di`/`do`/`dO` step into/over/out, `dt` terminate, `du` UI, `de` evaluate (n/x).
      IntelliJ keys: F7 into, F8 over, Shift+F8 out, F9 continue. Debug nearest test: `<leader>ud` (neotest dap strategy).
      `kickstart.plugins.debug` (Go-focused) stays unused.
- [ ] [verify] Java: breakpoint + `<leader>dc` on a main class, `<leader>ud` on a test, attach to `bootRun --debug-jvm`.
      Shift+F8 may not reach nvim in some terminals; `<leader>dO` always works.
- [x] [setup] Kotlin debugging via Mason `kotlin-debug-adapter` (fwcd; only Kotlin DAP, unmaintained since 2023 —
      kotlin_lsp has no debugger). Same `<leader>d` maps. Configs: "Launch main class" (default `<package>.<File>Kt`,
      runs compiled classes only — `./gradlew classes` first) and "Attach to JVM (localhost:5005)".
      Kotlin tests: `./gradlew test --tests '<name>' --debug-jvm`, then attach (`<leader>ud` is Java-only: neotest-gradle has no dap strategy).
- [ ] [verify] Kotlin: launch a `fun main`, attach to `bootRun --debug-jvm` / `test --debug-jvm`, breakpoints hit in `.kt` files.
      If the adapter fails on current Kotlin/JDK versions, fall back to IntelliJ for Kotlin debugging.
- [ ] [setup, optional] Make `<leader>ud` debug Kotlin tests too (run the gradle test with `--debug-jvm` and auto-attach;
      for now: `<leader>bb` → `gradle …` → `test --tests '<name>' --debug-jvm`, then attach)
- [ ] [skill] Breakpoints, conditional breakpoints, step over/into/out, evaluate expression
- [ ] [skill] `<leader>b` tasks instead of a terminal for builds; `<leader>bt` list: `<CR>` actions, `o` output, `dd` dispose, `?` help
- [ ] [skill] Built-in terminal: `:term`, `<Esc><Esc>` to leave terminal mode, terminal in splits

## 4. Editing

- [x] [setup] Autopairs enabled (`kickstart.plugins.autopairs`)
- [x] [setup] Formatter check: conform has no Java/Kotlin formatter and falls back to LSP (`<leader>f`): jdtls for Java,
      kotlin_lsp (IntelliJ's formatter) for Kotlin. Deliberately no google-java-format/ktfmt, to stay close to IntelliJ output.
      If Java output differs from the team's IntelliJ style, export the code style as Eclipse XML and point jdtls
      `settings.java.format.settings.url` at it.
- [ ] [setup] Snippets (live templates): enable friendly-snippets and/or write LuaSnip snippets for `psvm`, `sout`, test methods
- [ ] [skill] mini.ai objects: function `f`, argument `a`, quote `q` (`daf`, `cia`, `vi(`)
- [ ] [skill] mini.surround: `sa`, `sd`, `sr`
- [ ] [skill] `.` repeat, macros (`qa…q`, `@a`, `@@`), registers (`"+y`, `"0p`)
- [ ] [skill] Visual block `<C-v>` instead of multi-cursor; `:s` with `&` / `g&`; `:g/pattern/normal …`

## 5. Project-wide search and replace

- [ ] [skill] `<leader>sg` live grep → `<C-q>` to quickfix → `:cdo s/old/new/g | update` (IntelliJ Ctrl+Shift+R)
- [ ] [setup, optional] Interactive replace panel: `MagicDuck/grug-far.nvim` or `nvim-pack/nvim-spectre`

## 6. Git

- [x] [setup] Git client (`lua/custom/plugins/git.lua`): Neogit + codediff.nvim as diff viewer. diffview.nvim was skipped:
      no commits since 2024-06; codediff is maintained and covers diffs, history and 3-way conflicts.
      Maps: `<leader>gg` status (stage/commit/push), `gc` commit, `gb` branches, `gl` log, `gd` diff changes
      (conflicted files open in the 3-way view), `gD` diff against a revision, `gh` file history (visual: selection history),
      `gH` repo history. `git mergetool` opens codediff's merge view (`run_onchange_git_config.sh`).
- [x] [fix] Snap nvim (core22 glibc 2.35) can't load codediff's library with the host libgomp (needs glibc 2.38):
      `git.lua` downloads codediff's bundled old-glibc libgomp next to the library when running from snap.
      codediff failing no longer aborts startup (Neogit falls back to inline diffs). Cleaner long-term: non-snap nvim.
- [ ] [verify] codediff downloads its native diff library on first use (`:CodeDiff install` to retry); Neogit `d` popup opens codediff;
      resolve a real merge conflict with `<leader>gd` and with `git mergetool`
- [ ] [skill] Neogit status buffer: `s`/`u` stage/unstage, `c` commit, `P` push, `p` pull, `b` branch, `?` help
- [ ] [skill] gitsigns: stage/reset/preview hunks, blame line, `ih` hunk text object

## 7. Files, windows, layout

- [ ] [skill] neo-tree: create/rename/move files. Moving a Java file does not update its `package` line —
      fix it manually or via a jdtls code action.
- [ ] [skill] Splits (`<C-w>v`, `<C-w>s`, `<C-h/j/k/l>`), alternate file `<C-^>`, buffers vs tabs,
      `<leader><leader>` buffers, `<leader>s.` recent files
- [x] [setup] Sessions (`lua/custom/plugins/sessions.lua`): persistence.nvim, one session per cwd (and git branch other
      than main/master), saved on exit. Plain `nvim` in a project restores it; `nvim <files>` neither restores nor saves.
      Panels (neo-tree, dap-ui, neotest, overseer, quickfix, terminals) are closed before saving. Maps: `<leader>wr` restore,
      `ws` pick project, `wl` last session, `wd` don't save on exit. Chose it over mini.sessions for per-directory sessions without extra code.
- [ ] [verify] Reopen a Java project: buffers/splits come back, jdtls attaches, no empty panel windows
- [ ] [setup, optional] Pinned working set of files: `mini.visits` or harpoon

## 8. Config maintenance

- [ ] [skill] `:checkhealth`, `:checkhealth vim.lsp`, `:Mason`, `:messages`, `:Inspect`, `<leader>sk`, `<leader>sh`
- [ ] [skill] Update plugins: `:lua vim.pack.update()`
- [ ] [skill] Debug misbehaving adapters: `:lua vim.lsp.log.set_level 'debug'`, neotest log (`stdpath('log')`)

## Suggested order

1. ~~Call/type hierarchy maps, diagnostics navigation, quickfix workflow~~ (setup done, skills to practice)
2. ~~nvim-jdtls, autopairs, formatter check~~ (setup done, verify nvim-jdtls in a real project)
3. ~~Debugger (nvim-dap + nvim-jdtls)~~ (Java + Kotlin set up, verify)
4. ~~Git client + diffview~~ (Neogit + codediff set up, verify)
5. ~~Gradle/Maven task runner, sessions~~ (overseer + persistence set up, verify)

## Log

- 2026-10-22: Plan created. Fixed neotest-java failing on Kotlin-only projects; made mini.jump2d labels readable.
- 2026-10-22: Step 1 setup — call/type hierarchy maps, `<leader>Q` project errors to quickfix.
- 2026-10-22: Step 2 setup — nvim-jdtls with Lombok and `<leader>j` refactor maps, autopairs, formatter check (LSP fallback kept).
- 2026-10-22: Replaced Java-only `<leader>j` maps with language-agnostic `<leader>r` refactor maps.
- 2026-10-22: Moved LSP rename from `grn` to `<leader>rn` (built-in `grn` default removed).
- 2026-10-22: Step 3 setup — nvim-dap + dap-ui + virtual text, Java debugging via nvim-jdtls, `<leader>d` maps, `<leader>ud` debug test.
- 2026-10-22: Kotlin debugging via kotlin-debug-adapter (launch main class, attach on 5005).
- 2026-10-22: Step 4 setup — Neogit + codediff.nvim (instead of unmaintained diffview), `<leader>g` maps, codediff as git mergetool.
- 2026-10-22: Fixed codediff failing to load under snap nvim (bundle libgomp).
- 2026-10-23: Step 5 setup — overseer.nvim with Gradle/Maven tasks and compiler errors in quickfix (`<leader>b`), persistence.nvim sessions (`<leader>w`).
