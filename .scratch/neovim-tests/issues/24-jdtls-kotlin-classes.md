# Java code using Kotlin classes in mixed projects

Type: task
Status: resolved (limit accepted)
Blocked by: 16

## What

Known limit pinned by `tests/e2e/test_*_mixed.lua`: jdtls has no Kotlin support, so in mixed Java/Kotlin projects
Java code using Kotlin classes shows "cannot be resolved" errors and has no navigation, although Gradle and Maven
compile it. Options to evaluate: put the Kotlin compiler output (`build/classes/kotlin/main`, `target/classes`) on
jdtls' classpath after a build, or accept the limit (kotlin_lsp resolves Java from Kotlin).

## Acceptance

Either the known-limit test is flipped to "resolves" and green, or the limit is accepted and documented as such.

## Notes

- Tried on gradle-mixed: `gradle classes`, then jdtls started with `java.project.referencedLibraries` =
  `build/classes/kotlin/main/**`. Still "KotlinFormatter cannot be resolved to a type": jdtls uses the Gradle
  (Buildship) classpath for Gradle projects and ignores referencedLibraries there.
- Other routes need changes to the user's build files (e.g. Eclipse plugin classpath tweaks) or a Kotlin-aware
  Java server; not worth it here. Accepted: the known-limit tests in `test_*_mixed.lua` stay, and Kotlin files
  (kotlin_lsp) do resolve Java.
