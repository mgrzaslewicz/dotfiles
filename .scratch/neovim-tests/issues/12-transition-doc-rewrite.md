# Rewrite INTELLIJ_TRANSITION.md; move rationale to code

Type: task
Status: resolved
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

## Notes

- Kept beyond decision 13: an "Open ideas" list (the unstarted optional `[setup]` items), so future work is not lost.
- Where everything went (also in the commit message): Notes for agents → skill; `[verify]` → issue 13; rationale →
  Lua headers (debug, git, sessions, refactor, errorformat, conform in init.lua); setup descriptions and key lists
  dropped (the code, which-key and `<leader>sk` have them); Suggested order and Log dropped.
