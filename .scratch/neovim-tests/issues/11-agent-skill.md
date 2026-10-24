# Agent skill: testing the nvim config

Type: task
Status: resolved
Blocked by: 04

## What

Spec decisions 11, 12. `.claude/skills/<name>/SKILL.md` (root `.gitignore` un-ignores `.claude/skills/`
only; the rest of `.claude/` stays ignored).

Contents: `mise run setup|test|check`, test layout and child-nvim helper, `NVIM_TEST`, mandatory test-first
(red → green → check), spikes never committed as-is, the hook, plus the former "Notes for agents" from
`INTELLIJ_TRANSITION.md` (chezmoi source vs deploy, `vim.pack`, mason servers, language-agnostic keymaps,
prefix registry → `tests/test_keymaps.lua`).

## Acceptance

A fresh agent session asked to "add a feature to the nvim config" loads the skill and starts with a failing test.

## Notes

- Skill: `.claude/skills/nvim-config/SKILL.md`. Includes the former "Notes for agents" (removed from
  `INTELLIJ_TRANSITION.md` in issue 12), the "prove it bites" rule for tests that pass before the change, and the
  `[[ ]]` vs `[=[ ]=]` pitfall in `child.lua` chunks.
- Acceptance (fresh session starts with a failing test) not verified by a separate session; check on first use.
