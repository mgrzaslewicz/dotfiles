# Keymap prefix registry smoke test

Type: task
Status: open
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
