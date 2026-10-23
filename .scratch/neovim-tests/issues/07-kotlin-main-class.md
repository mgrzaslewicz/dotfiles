# Extract Kotlin main class naming

Type: task
Status: open
Blocked by: 02

## What

- Pure `kotlin_main_class(lines, filename)` → `'<package>.<File>Kt'` (or `'<File>Kt'` without package).
- `debug.lua` keeps the `vim.fn.input` prompt, using the function for the default.

## Acceptance

Tests: package present, no package, package after file-level annotations/comments, package beyond line 50 (current limit — decide and document).
