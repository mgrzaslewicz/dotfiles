# Java code using Kotlin classes in mixed projects

Type: task
Status: open
Blocked by: 16

## What

Known limit pinned by `tests/e2e/test_*_mixed.lua`: jdtls has no Kotlin support, so in mixed Java/Kotlin projects
Java code using Kotlin classes shows "cannot be resolved" errors and has no navigation, although Gradle and Maven
compile it. Options to evaluate: put the Kotlin compiler output (`build/classes/kotlin/main`, `target/classes`) on
jdtls' classpath after a build, or accept the limit (kotlin_lsp resolves Java from Kotlin).

## Acceptance

Either the known-limit test is flipped to "resolves" and green, or the limit is accepted and documented as such.
