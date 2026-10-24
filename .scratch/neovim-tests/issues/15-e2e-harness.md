# Layer B harness, tracer bullet: jdtls on gradle-java

Type: task
Status: resolved
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

## Notes

- Found by the tracer: jdtls v1.63.0 needs Java 25 (bundled Eclipse plugins require `osgi.ee JavaSE 25`); it
  exits with code 13 on 21. Health minimum, hint, comments and the mise pin moved to 25 — the host needs 25 too.
- Pins: `lua/custom/tools.lua` (Mason packages + parser list; kotlin-lsp registry override reads its version
  from there); mise: java temurin-25.0.5, gradle 9.8.2, maven 3.9.16, tree-sitter 0.27.1. Fixture Lombok 1.18.48.
- `tests/run.sh --e2e`: preflight → bootstrap (sync mason-tool-installer, parser install wait, verify against
  pins) → `tests/e2e/test_*.lua`. Layer A collection restricted to `tests/test_*.lua` (mini.test's default recurses).
- Row 1 readiness: `ServiceReady` (recorded by patching `jdtls.start_or_attach` in the child), definition of the
  Lombok getter reaches Person.java, the fixture's deliberate unused-import warning arrives, then no errors.
- Mutation: without the Lombok javaagent the definition wait times out.
- Preflight acceptance as layer A tests (`test_health.lua`, fake programs on PATH): missing unzip → exit 1,
  names it and the install hint, < 1 s.
- Times (this container): fresh e2e 47 s (downloads, 1.7 GB root), second run 6 s; layer A check 23 s, unchanged.
- Installed `unzip` and `gcc` in the container via apt (prerequisites).
