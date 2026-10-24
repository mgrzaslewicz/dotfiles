# Layer B: neotest on real projects

Type: task
Status: open
Blocked by: 16

## What

Spec decision 19 row 5.

- Run file on a test class with one passing and one failing test; assert results per test.
- Mixed projects: each test listed once (neotest-java vs neotest-gradle-kotlin).
- Kotlin tests in maven-mixed: found, or asserted as a known limit (follow-up issue for the fix).
- neotest-java fix for Kotlin-only projects covered by gradle-kotlin.

## Acceptance

gradle-java, gradle-kotlin, gradle-mixed, maven-mixed green or with named known limits.
