# Layer B: real compile errors in quickfix

Type: task
Status: resolved
Blocked by: 16

## What

Spec decision 19 row 4.

- Per fixture: introduce a compile error in the temp copy, run the build task through overseer
  (`<leader>bc` path), assert quickfix holds the right file/line/type; restore the file.
- Covers javac (Gradle, Maven), kotlinc (Gradle), kotlin-maven-plugin (maven-mixed).

## Acceptance

All five fixtures; any kotlinc format not matched becomes a new `test_errorformat.lua` case first.

## Notes

- Red first: all five fixtures had an empty quickfix list. Overseer's default strategy runs tasks in a terminal
  buffer, and `on_output_quickfix` re-parses that buffer on exit, replacing what it had tailed. A terminal buffer
  wraps lines at its width (`columns - 4`), so error lines with absolute paths were split and nothing matched,
  in a real UI too for deep paths. Fix: JVM tasks use `{ 'jobstart', use_terminal = false }` (layer A test in
  `test_tasks.lua`); task output loses colors.
- No new errorformat case needed: kotlinc 2.4 (`e: file:///…:3:21 …`), javac via Gradle and Maven, and
  kotlin-maven-plugin all matched. kotlinc's `e:` gives quickfix type `e` (shown as error); the helper compares
  upper case.
- Known limit, issue 25: javac errors (Gradle, Maven) and kotlin-maven-plugin errors are listed twice.
- The cases go through `<leader>bc` with `vim.ui.select` answered by the task name (`e2e.compile_errors`).
