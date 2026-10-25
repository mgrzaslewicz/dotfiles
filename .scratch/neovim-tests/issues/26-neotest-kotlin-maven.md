# Kotlin tests in Maven projects

Type: task
Status: open
Blocked by: 18

## What

Known limit pinned by `tests/e2e/test_maven_mixed.lua`: `<leader>uf` on a Kotlin test in a Maven project says
"No tests found". neotest-gradle only roots at a Gradle build file, and neotest-java is limited to `.java`
in `custom/plugins/neotest.lua` (it claims `*Test.kt` by name and then fails looking for Java sources).

Options: a small Maven Kotlin adapter (discovery via neotest-gradle's Kotlin query, run `mvn test -Dtest=…`
at the module, read `target/surefire-reports/*.xml`); try whether neotest-java's JUnit console launcher run
works for Kotlin classes when compiled by Maven; or accept the limit (run `mvn test` via `<leader>b`).
