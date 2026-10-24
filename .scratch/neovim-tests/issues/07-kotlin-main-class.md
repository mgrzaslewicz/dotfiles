# Extract Kotlin main class naming

Type: task
Status: resolved
Blocked by: 02

## What

- Pure `kotlin_main_class(lines, filename)` → `'<package>.<File>Kt'` (or `'<File>Kt'` without package).
- `debug.lua` keeps the `vim.fn.input` prompt, using the function for the default.

## Acceptance

Tests: package present, no package, package after file-level annotations/comments, package beyond line 50 (current limit — decide and document).

## Notes

- Module: `lua/custom/jvm/kotlin.lua`, `main_class(lines, filename)`; `debug.lua` passes the whole buffer and
  keeps the `vim.fn.input` prompt.
- Line limit dropped: the package header precedes imports and code, so the first `package` line wins, after any
  length of license header.
- Fixed on the way (test-first): kotlinc capitalizes the file name (`main.kt` → `MainKt`, was `mainKt`) and
  replaces invalid characters with `_`; `@file:JvmName("X")` replaces the `<File>Kt` name.
- Smoke test `tests/test_debug.lua`: the Kotlin launch config prompts with the current file's main class.
