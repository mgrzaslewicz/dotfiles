# Layer B: end-to-end tests with real LSP/DAP

Type: grilling
Status: open
Blocked by: 12

## Question

How to automate the `[verify]` items: fixture Gradle/Maven/Kotlin projects, JDK in the test env (mise `java`?),
Mason installs without `NVIM_TEST`, run time and flakiness budget, whether it runs in the hook or on demand only,
which items stay manual (terminal key delivery, interactive DAP UI). Includes: does kotlin-debug-adapter need
`project.module` or `project.root` as `projectRoot` in multi-module builds?

## Answer
