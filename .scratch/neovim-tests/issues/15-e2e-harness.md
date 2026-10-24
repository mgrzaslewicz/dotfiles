# Layer B harness, tracer bullet: jdtls on gradle-java

Type: task
Status: open
Blocked by: 13

## What

Spec decisions 16–22, 24. Everything layer B needs, proven on one check.

- `mise run test:e2e` (optionally one file); `tests/run.sh` takes the state root as a parameter
  (`tests/.tests` vs `tests/.tests-e2e`), e2e runs without `NVIM_TEST`.
- Pins: `java`, `gradle`, `maven`, `tree-sitter` in the repo `mise.toml`; Mason package versions in
  `ensure_installed` (`init.lua`), with the update flow in the skill.
- Prerequisites list in `custom/health.lua` (JDK version for jdtls, `cc`, `unzip`, `tree-sitter`):
  `:checkhealth custom` reports them; `test:e2e` preflight fails fast with install hints. Unit/smoke
  tested in layer A.
- `tests/e2e/helpers.lua`: fixture copy to a temp dir, Gradle/Maven caches in the e2e root, condition
  waits with named timeouts × `E2E_TIMEOUT_FACTOR`, failure dump (`:messages`, LSP log tail, task output,
  DAP events).
- Fixture `tests/e2e/fixtures/gradle-java` (multi-module, Lombok, JUnit 5).
- `tests/e2e/test_gradle_java.lua`: row 1 — jdtls attaches, a Lombok getter use has no diagnostics.
- Skill: when to run e2e, `[manual]` checks list, e2e layout.

## Acceptance

- Fresh `rm -rf tests/.tests-e2e && mise run test:e2e` installs everything and passes.
- Second run reuses installs; time recorded in the notes.
- Layer A (`mise run check`) unchanged in time and still hermetic.
- Preflight with `unzip` hidden from PATH fails in under a second naming it.
