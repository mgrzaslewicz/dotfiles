# Layer B: Kotlin debugging, settle debug_root

Type: task
Status: resolved
Blocked by: 16

## What

Spec decision 19 row 7; decision 7 open question.

- Launch `fun main` and attach to `gradle run --debug-jvm` (and the Maven equivalent), breakpoint hit in
  a `.kt` file, started from a subproject/module file.
- Try `projectRoot` = build root and = module for both build tools; keep what works, test-first:
  rename `project.debug_root` to what it is (`module`, or use `root`).

## Acceptance

gradle-kotlin and maven-mixed green, or kotlin-debug-adapter limits asserted; spec decision 7 updated.

## Notes

- Launch works on gradle-kotlin from the `app` module (`e2e.debug_until_stopped` with a breakpoint in `lib`,
  `e2e.debug_to_end` checks the program output). Compiled first with `gradle classes` (launch does not build).
- Breakpoints in the launched main class itself are mostly missed (2 of 3 attempts in a probe); breakpoints in
  classes loaded later were hit 3 of 3. Documented in debug.lua, not pinned (not deterministic).
- `debug_root` settled, no rename: Gradle build root (module root: frame shown in the wrong file), Maven module
  (build root: `ClassNotFoundException` for the main class). Spec decision 7 updated.
- Known limit, pinned in maven-mixed: launching from a module that uses a sibling module ends in
  `NoClassDefFoundError`; the adapter takes sibling modules only from `~/.m2` (it ignores `-Dmaven.repo.local`,
  so `mvn install` could not be tried in the isolated e2e env).
- Attach to `gradle run --debug-jvm`: the adapter connects and verifies breakpoints, but no stop reaches nvim
  and later requests (threads, stackTrace) go unanswered. Resuming threads after attach (tried on
  configurationDone, which the adapter does not support, on `initialized`, and after the attach response) did
  not help. Not pinned: no reliable signal. Documented in debug.lua.
- Harness: `e2e.errors` now re-pulls diagnostics up to three times while errors remain; kotlin-lsp answered a
  first pull before indexing ("Unresolved reference 'println'"), twice in these runs.
