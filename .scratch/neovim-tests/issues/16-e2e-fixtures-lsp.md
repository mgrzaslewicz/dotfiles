# Layer B: remaining fixtures, LSP attach on all

Type: task
Status: resolved
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

## Notes

- All five fixtures green, full e2e suite 69 s (warm caches).
- Fixed on the way (layer A, test-first, own commits): Maven multi-module roots — `project.root` stopped at a
  module's pom.xml, and jdtls/kotlin_lsp did the same, hiding sibling modules (found by maven-java); session leak
  between layer A children (found when a new test opened a .java file).
- Known limit, asserted: jdtls has no Kotlin support — Java code using Kotlin classes is unresolved in both mixed
  fixtures (follow-up: issue 24). Kotlin → Java works through kotlin_lsp.
- Harness lessons: waits are now runner-side polls with async LSP requests (a blocking wait inside the child hung
  a run for 30+ min); `definition_reaches` takes the column from the regex match; kotlin-lsp reports no unused
  variables, so Kotlin fixtures anchor on an unnecessary `!!`.
- Fixtures build from the CLI with exactly one failing test each (for issue 18). Versions: Kotlin 2.4.21,
  JUnit 5.14.4, Lombok 1.18.48, maven-compiler 3.16.0, surefire 3.6.0.
