# Keymap prefix registry smoke test

Type: task
Status: resolved
Blocked by: 02

## What

Spec decision 15.

- One table of `<leader>` groups → expected desc prefix: `u` test, `h` hunk, `g` git, `s` search, `t` toggle,
  `r` refactor, `d` debug, `b` build, `w` sessions.
- Test reads `nvim_get_keymap` per mode after full startup and asserts each mapping under a group carries its prefix,
  and no lhs is defined twice per mode.

## Acceptance

Test passes on current config, or each violation is fixed (not allowlisted) in this issue. Buffer-local maps
(LSP/refactor) are covered via a fake LSP attach.

## Notes

- `nvim_get_keymap` cannot show a map set twice (the later set replaces it), so the test wraps `vim.keymap.set` via
  `--cmd` before init.lua and records every `<leader>` map. Per-buffer maps come from a file in a temp git repo
  (gitsigns) with the fake LSP attached (now `helpers.attach_fake_lsp`, shared with test_refactor.lua).
- Rules: maps of 3+ keys must be in a registered group (new groups start in the registry) with the desc prefix;
  no map set twice in the same scope (global, or the same buffer); no buffer map shadowing a global one. The test
  also asserts every group was reached, so the setup cannot silently miss gitsigns or LSP.
- Prefixes as found: `h` is `git ` (gitsigns, kickstart style), `s` `[S]earch`, `t` `[T]oggle`.
- Violation fixed: LSP `<leader>th` desc was `LSP: [T]oggle Inlay [H]ints`.
- Mutation check: a second global `<leader>gg` and a buffer `<leader>gl` are both reported.
