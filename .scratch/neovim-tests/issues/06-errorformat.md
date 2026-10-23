# Extract JVM errorformat, quickfix smoke test

Type: task
Status: open
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
