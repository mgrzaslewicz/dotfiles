# Layer B: end-to-end tests with real LSP/DAP

Type: grilling
Status: open
Blocked by: 12

## Question

How to automate the `[verify]` items: fixture Gradle/Maven/Kotlin projects, JDK in the test env (mise `java`?),
Mason installs without `NVIM_TEST`, run time and flakiness budget, whether it runs in the hook or on demand only,
which items stay manual (terminal key delivery, interactive DAP UI). Includes: does kotlin-debug-adapter need
the module or the build root as `projectRoot` in multi-module builds (today: `project.debug_root`)?

## Manual checks carried over from INTELLIJ_TRANSITION.md

Each one: automate in layer B, or keep as a documented manual check.

- Java project: jdtls attaches (`:checkhealth vim.lsp`), Lombok getters resolve, `<leader>ua` runs tests.
- `<leader>r` maps in Kotlin and Rust; servers whose extract action titles differ need new title words or a handler.
- Gradle and Maven projects: task list shows up, a compile error lands in quickfix with the right file/line,
  `bootRun --debug-jvm` + `<leader>dc` "Attach" works.
- Java debug: breakpoint + `<leader>dc` on a main class, `<leader>ud` on a test, attach to `bootRun --debug-jvm`.
- Kotlin debug: launch a `fun main`, attach to `bootRun --debug-jvm` / `test --debug-jvm`, breakpoints hit in `.kt`.
- codediff downloads its native library on first use (`:CodeDiff install` to retry); Neogit `d` popup opens
  codediff; resolve a real merge conflict with `<leader>gd` and with `git mergetool`.
- Reopen a Java project: buffers/splits come back, jdtls attaches, no empty panel windows.

## Answer
