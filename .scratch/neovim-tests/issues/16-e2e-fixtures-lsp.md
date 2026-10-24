# Layer B: remaining fixtures, LSP attach on all

Type: task
Status: open
Blocked by: 15

## What

Spec decisions 18, 19 rows 1–2.

- Fixtures `gradle-kotlin`, `gradle-mixed`, `maven-java` (multi-module), `maven-mixed` (Java + Kotlin
  calling each other), each with a test class and a failing-able source file for later rows.
- One test file per fixture; row 1 (jdtls, Lombok where present) and row 2 (kotlin_lsp, right server
  per file in mixed projects).

## Acceptance

Rows 1–2 green on all five fixtures, or known limits asserted (e.g. kotlin_lsp on Maven) and named in the
Lua header of the wiring.
