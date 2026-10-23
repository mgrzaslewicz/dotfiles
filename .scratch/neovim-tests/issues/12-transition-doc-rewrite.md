# Rewrite INTELLIJ_TRANSITION.md; move rationale to code

Type: task
Status: open
Blocked by: 05, 06, 07, 08, 09, 10, 11

## What

Spec decisions 13, 14.

- Plan keeps: goal summary, `[skill]` list, per-feature pointers to test files, "no tests yet" list
  (hierarchy maps, `go_to_class`, jdtls wiring, `<leader>Q`, debug maps, git, sessions, highlights,
  neotest-java Kotlin fix, mini.jump2d labels).
- Drop `[setup]`/`[verify]` items and the Log. Unautomated `[verify]` items carry over to issue 13.
- Rationale and known limits → header comments in the matching Lua files.

## Acceptance

No rationale lost: every removed note is either in a Lua header comment, the skill, issue 13, or deliberately dropped (listed in the commit message).
