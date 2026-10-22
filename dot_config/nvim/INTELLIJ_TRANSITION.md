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
- Leader is `<Space>`. Test maps use `<leader>u`, git hunk maps `<leader>h`, search maps `<leader>s`, toggles `<leader>t`.
  Check `<leader>sk` / which-key for conflicts before adding maps.
- Keymaps are language-agnostic: one key per action for all languages. Add language-specific behaviour behind the
  shared keys (e.g. `require('custom.refactor').register` for `<leader>r`), never per-language prefixes.

## Already in place

- [x] File navigation, vim motions, mini.jump2d, Telescope file/grep search, LSP symbol search (`gO`, `gW`)
- [x] LSP: `grd` definition, `grr` references, `gri` implementation, `grt` type definition, `grn` rename, `gra` code action, `K` hover
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
- [x] [setup] Language-agnostic refactor maps (`lua/custom/refactor.lua`), any LSP buffer: `<leader>ro` organize imports,
      `rv`/`rV` extract variable (all occurrences), `rc` extract constant, `rm` extract method (visual).
      Default = matching LSP code action; Java uses nvim-jdtls via `require('custom.refactor').register(bufnr, handlers)`.
- [ ] [verify] `<leader>r` maps in Kotlin and Rust; if a server titles its extract actions differently, adjust the
      title words in `refactor.lua` or register a handler for that language
- [ ] [skill] `<leader>r` refactors (IntelliJ Ctrl+Alt+O / V / C / M)
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

- [ ] [setup] Task runner for Gradle/Maven (Run Configurations equivalent). Options: `stevearc/overseer.nvim`,
      or `makeprg=./gradlew` + `:make` so compile errors go to quickfix.
- [ ] [setup] Debugger: `nvim-dap` + `nvim-dap-ui` + nvim-jdtls Java DAP (`lua/kickstart/plugins/debug.lua` exists, commented out in `init.lua`).
      Kotlin: attach to a JVM started with `-agentlib:jdwp` via the Java adapter.
- [ ] [skill] Breakpoints, conditional breakpoints, step over/into/out, evaluate expression
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

- [ ] [setup] Full git client: `tpope/vim-fugitive` or `NeogitOrg/neogit` (commit, branches, log)
- [ ] [setup] `sindrets/diffview.nvim` for file history and 3-way merge conflicts (IntelliJ merge tool)
- [ ] [skill] gitsigns: stage/reset/preview hunks, blame line, `ih` hunk text object

## 7. Files, windows, layout

- [ ] [skill] neo-tree: create/rename/move files. Moving a Java file does not update its `package` line —
      fix it manually or via a jdtls code action.
- [ ] [skill] Splits (`<C-w>v`, `<C-w>s`, `<C-h/j/k/l>`), alternate file `<C-^>`, buffers vs tabs,
      `<leader><leader>` buffers, `<leader>s.` recent files
- [ ] [setup] Sessions (reopen project as left): `mini.sessions` (already in mini.nvim, not enabled) or `folke/persistence.nvim`
- [ ] [setup, optional] Pinned working set of files: `mini.visits` or harpoon

## 8. Config maintenance

- [ ] [skill] `:checkhealth`, `:checkhealth vim.lsp`, `:Mason`, `:messages`, `:Inspect`, `<leader>sk`, `<leader>sh`
- [ ] [skill] Update plugins: `:lua vim.pack.update()`
- [ ] [skill] Debug misbehaving adapters: `:lua vim.lsp.log.set_level 'debug'`, neotest log (`stdpath('log')`)

## Suggested order

1. ~~Call/type hierarchy maps, diagnostics navigation, quickfix workflow~~ (setup done, skills to practice)
2. ~~nvim-jdtls, autopairs, formatter check~~ (setup done, verify nvim-jdtls in a real project)
3. Debugger (nvim-dap + nvim-jdtls)
4. Git client + diffview
5. Gradle/Maven task runner, sessions

## Log

- 2026-10-22: Plan created. Fixed neotest-java failing on Kotlin-only projects; made mini.jump2d labels readable.
- 2026-10-22: Step 1 setup — call/type hierarchy maps, `<leader>Q` project errors to quickfix.
- 2026-10-22: Step 2 setup — nvim-jdtls with Lombok and `<leader>j` refactor maps, autopairs, formatter check (LSP fallback kept).
- 2026-10-22: Replaced Java-only `<leader>j` maps with language-agnostic `<leader>r` refactor maps.
