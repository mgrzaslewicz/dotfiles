# Layer B: end-to-end tests with real LSP/DAP

Type: grilling
Status: resolved
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

Spec decisions 16–24 (`spec.md`, "Layer B"). In short:

- Q1 On demand only, `mise run test:e2e`; not in `check` or the hook.
- Q2 Pin everything: Mason versions in the config, JDK in `mise.toml`.
- Q3 Committed fixtures, no wrappers: gradle-java, gradle-kotlin, gradle-mixed, maven-java, maven-mixed
  (mixed requested by the user; maven-mixed adds kotlin-maven-plugin errors, Kotlin tests in Maven,
  Maven `projectRoot`, kotlin_lsp on Maven).
- Q4 All nine automated checks; manual: Shift+F8, dap-ui look, `git mergetool`, Rust refactor titles.
- Q5 One file per fixture, one shared child, cases clean up.
- Q6 Condition waits, named timeouts, no retries, failure dump.
- Q7 Separate root `tests/.tests-e2e/`.
- Q8 Gaps become known-limit assertions; fixes are separate issues.
- Q9 Prerequisites listed in `custom/health.lua`: e2e preflight + `:checkhealth custom`.
- Q10 Issues 15 (harness + tracer on gradle-java row 1), then 16–23 per row.

