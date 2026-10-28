# IntelliJ → Neovim

Goal: Neovim as the daily IDE for Java/Kotlin work, replacing IntelliJ. The config is treated as a software project:
its features are specified by the tests in `tests/`, and changes are made test-first. Working on the config (agents
and humans): `.claude/skills/nvim-config/SKILL.md` at the repo root. Rationale and known limits of each feature are
in the header comment of its Lua file.

## Features and their tests

| Feature (IntelliJ) | Code | Tests |
|---|---|---|
| Config starts without errors or messages | `init.lua` | `test_startup.lua` |
| `<leader>` groups and desc prefixes, no duplicate maps | all | `test_keymaps.lua` |
| Gradle/Maven tasks (Run Configurations, Ctrl+F9), compiler errors in quickfix | `lua/custom/plugins/tasks.lua`, `lua/custom/jvm/` | `test_tasks.lua`, `test_project.lua`, `test_errorformat.lua`, `e2e/test_*.lua` (real javac/kotlinc errors) |
| Sessions: reopen the project as left, without panels | `lua/custom/plugins/sessions.lua` | `e2e/test_gradle_java.lua` |
| Java debug: launch main class, debug nearest test (`<leader>db`, `<leader>dc`, `<leader>ud`) | `lua/custom/plugins/debug.lua`, `jdtls.lua` | `e2e/test_gradle_java.lua` |
| Kotlin debug: launch main class, project root | `lua/custom/plugins/debug.lua`, `lua/custom/jvm/` | `test_debug.lua`, `test_kotlin.lua`, `test_project.lua`, `e2e/test_gradle_kotlin.lua`, `e2e/test_maven_mixed.lua` |
| Refactor maps `<leader>r` (Shift+F6, Ctrl+Alt+O/V/C/M) | `lua/custom/refactor.lua` | `test_refactor.lua`, `e2e/test_gradle_java.lua`, `e2e/test_gradle_kotlin.lua` |
| Git client survives a broken codediff; codediff downloads its library, `<leader>gd` diff view | `lua/custom/plugins/git.lua` | `test_git.lua`, `e2e/test_codediff.lua` |
| Tested nvim version, prerequisites, `:checkhealth custom` | `lua/custom/health.lua` | `test_health.lua` |
| Pinned Mason packages and parsers | `lua/custom/tools.lua` | `test_tools.lua`, e2e bootstrap |
| JVM servers rooted at the whole build (Maven multi-module too) | `lua/custom/jvm/project.lua`, `jdtls.lua`, `init.lua` | `test_lsp_roots.lua`, `test_project.lua` |
| Java LSP (jdtls, Lombok) on Gradle and Maven | `lua/custom/plugins/jdtls.lua` | `e2e/test_gradle_java.lua`, `e2e/test_maven_java.lua` |
| Kotlin LSP (kotlin_lsp) on Gradle and Maven, mixed projects (one server per language) | `init.lua` | `e2e/test_gradle_kotlin.lua`, `e2e/test_*_mixed.lua` |
| Python LSP (pyright) enabled and rooted at the project; navigation across packages not yet covered by a layer B fixture | `init.lua`, `lua/custom/tools.lua` | `test_python.lua`, `test_tools.lua` |
| Run tests (JUnit 5, Java and Kotlin on Gradle and Maven), results in the gutter | `lua/custom/plugins/neotest.lua` | `test_neotest.lua`, `e2e/test_gradle_*.lua`, `e2e/test_maven_mixed.lua` |

## No tests yet

Backfilled when next touched (layer B plan: `.scratch/neovim-tests`, issues 16–23):

- Call/type hierarchy maps `grc`/`grC`/`grh`/`grH` (`init.lua`)
- Go to class `gC` (`lua/custom/go_to_class.lua`)
- nvim-jdtls wiring beyond attach/Lombok: refactor handlers, debug bundle, hot code replace (`lua/custom/plugins/jdtls.lua`)
- `<leader>Q` project errors to quickfix (`init.lua`)
- Debug F-keys and stepping maps, Java attach config, dap-ui open/close (`lua/custom/plugins/debug.lua`)
- Neogit/codediff maps `<leader>g`, codediff as `git mergetool` (`lua/custom/plugins/git.lua`)
- Sessions: no restore/save when started with files, `<leader>w` maps (`lua/custom/plugins/sessions.lua`)
- IntelliJ-style highlights, readable mini.jump2d labels (`lua/custom/highlights.lua`)
- LSP formatting fallback for Java/Kotlin, autopairs (`init.lua`)

## Open ideas

Proposals, ranked by daily-use value for Java/Kotlin. Each lands test-first (see the skill). Not yet decided.

### High value

- Snippets (live templates) for `psvm`, `sout`, test methods: enable friendly-snippets (commented out in `init.lua`) and/or add custom LuaSnip snippets for Java/Kotlin. Cheap win.
- Inline debugger values: `nvim-dap-virtual-text` shows variable values at line end while stepping, as IntelliJ does. Today values need hover or dap-ui panels. Wiring in `lua/custom/plugins/debug.lua`.
- Non-LSP linting: `kickstart/plugins/lint.lua` is disabled. Add `nvim-lint` with `ktlint` or `detekt` (Kotlin) and `checkstyle` (Java). kotlin-lsp does not report unused variables, so this fills an inspection gap.
- Tree-sitter textobjects and motions: `nvim-treesitter-textobjects` for method/class jumps (`]m`, `[m`), function/class objects, parameter swap. mini.ai covers only part of this. Parsers are already pinned in `lua/custom/tools.lua`.
- Project-wide replace panel: grug-far.nvim (or nvim-spectre) for Ctrl+Shift+R with preview and per-hunk apply. Today it is `:cdo` from quickfix: works, clumsy.

### Medium value

- Quick terminal: toggleable floating or bottom terminal (`snacks.terminal` or `toggleterm`). Today only `:term`.
- Breadcrumbs: `nvim-navic` in winbar, the IntelliJ path bar. Helps in deep Java packages.
- Pinned working set of files: mini.visits or harpoon.
- Indent scope: `mini.indentscope` (kickstart `indent_line` is off). Cosmetic, IntelliJ-like.
- Formatting check: confirm conform covers Java (`google-java-format`) and Kotlin (`ktlint`). The LSP-formatting fallback for Java/Kotlin has no tests; if conform misses either, that is a gap to fix.
- Coverage: neotest coverage display (JaCoCo) for Gradle and Maven. Stands in for IntelliJ "Run with coverage". Needs layer B, since it needs real builds.

### Unranked

- `<leader>ud` debugging Kotlin tests (run the Gradle test with `--debug-jvm` and auto-attach)

## Skills to practice

### Code intelligence

- [ ] `grc`/`grC`/`grh`/`grH` instead of grepping for callers and implementors (Ctrl+Alt+H, Ctrl+H)
- [ ] `gC` go to class (Ctrl+N), with package words: `java.io InputStream`, `util HM`
- [ ] `<leader>r` refactors (Shift+F6, Ctrl+Alt+O / V / C / M)
- [ ] `<C-o>` / `<C-i>` jump back/forward (Ctrl+Alt+←/→)
- [ ] `gra` as Alt+Enter: imports, quick fixes, generate…
- [ ] Completion keys: `<C-space>`, `<C-y>` accept, `<C-k>` signature

### Diagnostics and quickfix

- [ ] `]d` / `[d` next/prev diagnostic, `<C-w>d` diagnostic float (F2 / Shift+F2)
- [ ] `<leader>sd` workspace diagnostics, `<leader>q` buffer location list, `<leader>Q` project errors in quickfix
- [ ] Quickfix workflow: `:copen`, `]q` / `[q`, `:cdo` — grep results, test failures and build errors all land here

### Build, run, debug

- [ ] Breakpoints, conditional breakpoints, step over/into/out, evaluate expression (`<leader>d`, F7/F8/F9)
- [ ] `<leader>b` tasks instead of a terminal for builds; `<leader>bt` list: `<CR>` actions, `o` output, `dd` dispose, `?` help
- [ ] Built-in terminal: `:term`, `<Esc><Esc>` to leave terminal mode, terminal in splits

### Editing

- [ ] mini.ai objects: function `f`, argument `a`, quote `q` (`daf`, `cia`, `vi(`)
- [ ] mini.surround: `sa`, `sd`, `sr`
- [ ] `.` repeat, macros (`qa…q`, `@a`, `@@`), registers (`"+y`, `"0p`)
- [ ] Visual block `<C-v>` instead of multi-cursor; `:s` with `&` / `g&`; `:g/pattern/normal …`

### Project-wide search and replace

- [ ] `<leader>sg` live grep → `<C-q>` to quickfix → `:cdo s/old/new/g | update` (Ctrl+Shift+R)

### Git

- [ ] Neogit status buffer (`<leader>gg`): `s`/`u` stage/unstage, `c` commit, `P` push, `p` pull, `b` branch, `?` help
- [ ] gitsigns: stage/reset/preview hunks, blame line, `ih` hunk text object

### Files, windows, layout

- [ ] neo-tree: create/rename/move files. Moving a Java file does not update its `package` line — fix it manually
      or via a jdtls code action.
- [ ] Splits (`<C-w>v`, `<C-w>s`, `<C-h/j/k/l>`), alternate file `<C-^>`, buffers vs tabs, `<leader><leader>` buffers,
      `<leader>s.` recent files
- [ ] Sessions: `<leader>wr` restore, `ws` pick project, `wl` last session, `wd` don't save on exit

### Config maintenance

- [ ] `:checkhealth`, `:checkhealth custom`, `:checkhealth vim.lsp`, `:Mason`, `:messages`, `:Inspect`, `<leader>sk`, `<leader>sh`
- [ ] Update plugins: `:lua vim.pack.update()`, then commit `nvim-pack-lock.json` (see the skill)
- [ ] Debug misbehaving adapters: `:lua vim.lsp.log.set_level 'debug'`, neotest log (`stdpath('log')`)
