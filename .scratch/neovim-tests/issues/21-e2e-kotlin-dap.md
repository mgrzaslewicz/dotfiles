# Layer B: Kotlin debugging, settle debug_root

Type: task
Status: open
Blocked by: 16

## What

Spec decision 19 row 7; decision 7 open question.

- Launch `fun main` and attach to `gradle run --debug-jvm` (and the Maven equivalent), breakpoint hit in
  a `.kt` file, started from a subproject/module file.
- Try `projectRoot` = build root and = module for both build tools; keep what works, test-first:
  rename `project.debug_root` to what it is (`module`, or use `root`).

## Acceptance

gradle-kotlin and maven-mixed green, or kotlin-debug-adapter limits asserted; spec decision 7 updated.
