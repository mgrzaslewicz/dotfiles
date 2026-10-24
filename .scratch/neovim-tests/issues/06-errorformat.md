# Extract JVM errorformat, quickfix smoke test

Type: task
Status: resolved
Blocked by: 02

## What

Slice 1 items 4–5.

- Pure module exporting the errorformat string; `tasks.lua` uses it.
- Unit tests feed sample lines through `vim.fn.setqflist({}, ' ', { lines = …, efm = … })` and assert `getqflist()` entries.
- Smoke test: `gradle/maven` overseer template is registered in the full config.

## Acceptance

Test cases: javac error and warning, kotlinc `e: file:///…:12:5`, old kotlinc `e: /path/Foo.kt: (12, 5): …`,
Maven `[ERROR] /…:[12,5]`, `[WARNING]`, kotlin-maven-plugin `[ERROR] file:///…`.
Each asserts filename, lnum, col, type, text. Plus a non-matching line (e.g. Gradle progress output) yields no valid entry.

## Notes

- Module: `lua/custom/jvm/errorformat.lua` (returns the string). Unit tests parse with
  `getqflist({ lines, efm })`, which touches no quickfix list; types compared upper-cased (`e` vs `E`).
- Extra cases beyond acceptance: kotlinc `w:` warning, Maven `[INFO] BUILD FAILURE`, Gradle `BUILD SUCCESSFUL`.
- Smoke test `tests/test_tasks.lua` lists overseer templates in a child on fixture projects: Gradle task names,
  wrapper cmd and build-root cwd, Spring Boot task for Maven, and the quickfix component's errorformat equals the
  module's (guards against tasks.lua drifting back to a local copy).
- Mutation checks: dropping the old-kotlinc and Maven-warning patterns fails 2 cases; changing the errorformat in
  tasks.lua fails the smoke case.
