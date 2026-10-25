# Layer B: neotest on real projects

Type: task
Status: resolved
Blocked by: 16

## What

Spec decision 19 row 5.

- Run file on a test class with one passing and one failing test; assert results per test.
- Mixed projects: each test listed once (neotest-java vs neotest-gradle-kotlin).
- Kotlin tests in maven-mixed: found, or asserted as a known limit (follow-up issue for the fix).
- neotest-java fix for Kotlin-only projects covered by gradle-kotlin.

## Acceptance

gradle-java, gradle-kotlin, gradle-mixed, maven-mixed green or with named known limits.

## Notes

- neotest discovers lazily: nothing is listed before the first run, so cases start with `<leader>uf`
  (`e2e.neotest_run_file`) and read the listing and gutter signs after.
- Bug, red first: every Kotlin test (gradle-kotlin, gradle-mixed) showed as skipped. neotest-gradle asks Gradle
  for `testResultsDir`, which Gradle 9 answers with `null`, so it read reports from `null/test`. Fixed in
  `custom/plugins/neotest.lua` with the module's `build/test-results/test` (layer A `test_neotest.lua`). Run all
  had a second bug: neotest-gradle read only the root project's reports, so tests in modules were skipped; the
  override now reads every `build/test-results/test` below the run's root.
- neotest-gradle shows Kotlin test names in words ("fails on purpose"); asserted as is.
- Mixed: each test file listed by exactly one adapter (neotest-java for .java, neotest-gradle-kotlin for .kt).
- The neotest-java guard for Kotlin-only projects only matters for run all (`<leader>ua`); the gradle-kotlin
  run-all case catches its removal ("No Java file found" in :messages).
- Upstream limit, noted in the neotest header: after `:bwipeout` of a test buffer with failures the next run
  errors in neotest's diagnostic consumer; the e2e cleanup uses `%bdelete!` (also avoids an nvim-jdtls error).
- Known limit, issue 26: Kotlin tests in Maven are not found.
- The e2e bootstrap downloads neotest-java's JUnit console launcher (`:NeotestJava setup`).
- Seen once: kotlin-lsp reported `Unresolved reference 'println'` in gradle-kotlin's first case (index race).
