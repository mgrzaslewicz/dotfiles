# Layer B: real compile errors in quickfix

Type: task
Status: open
Blocked by: 16

## What

Spec decision 19 row 4.

- Per fixture: introduce a compile error in the temp copy, run the build task through overseer
  (`<leader>bc` path), assert quickfix holds the right file/line/type; restore the file.
- Covers javac (Gradle, Maven), kotlinc (Gradle), kotlin-maven-plugin (maven-mixed).

## Acceptance

All five fixtures; any kotlinc format not matched becomes a new `test_errorformat.lua` case first.
