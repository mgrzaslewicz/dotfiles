# Kotlin tests in Maven projects

Type: task
Status: resolved
Blocked by: 18

## What

Known limit pinned by `tests/e2e/test_maven_mixed.lua`: `<leader>uf` on a Kotlin test in a Maven project says
"No tests found". neotest-gradle only roots at a Gradle build file, and neotest-java is limited to `.java`
in `custom/plugins/neotest.lua` (it claims `*Test.kt` by name and then fails looking for Java sources).

Options: a small Maven Kotlin adapter (discovery via neotest-gradle's Kotlin query, run `mvn test -Dtest=…`
at the module, read `target/surefire-reports/*.xml`); try whether neotest-java's JUnit console launcher run
works for Kotlin classes when compiled by Maven; or accept the limit (run `mvn test` via `<leader>b`).

## Notes

- `neotest-maven-kotlin` in `custom/plugins/neotest.lua`: root = the Maven build (`project.root`), `*Test.kt`
  files, discovery and position ids from neotest-gradle's Kotlin query. Runs `mvn test` at the build root, with
  `-pl <module> -am -Dtest=<Class>[#method] -Dsurefire.failIfNoSpecifiedTests=false` for a file or test
  (`-am` builds the sibling modules the tests use).
- Results: its own parser of `target/surefire-reports/TEST-*.xml`. neotest-gradle's parser reads every file in
  the directory and failed ("Error Parsing XML") on surefire's `.txt` summaries; it also ignores `<error>`.
- Layer A: `test_neotest.lua` (commands for test/file/run all, results with a .txt summary and an errored test).
  e2e: maven-mixed's Kotlin test file now has per-test results (was the known limit).
