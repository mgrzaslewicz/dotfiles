# Extract `project` module: root, module, Spring Boot detection

Type: task
Status: open
Blocked by: 02

## What

Spec decision 7; slice 1 item 5.

- New pure module (e.g. `lua/custom/jvm/project.lua`):
  - `root(dir)` → `{ tool, root, cmd }|nil`, priority `gradlew`/`mvnw` > `settings.gradle*` > `build.gradle*`/`pom.xml`.
  - `module(dir)` → nearest module dir (current `kotlin_project_root` behaviour), else `nil` (caller decides on cwd fallback).
  - `uses_spring_boot(root)`.
- `tasks.lua` uses `root` + `uses_spring_boot`; `debug.lua` uses `module`.
- Test-first, fixtures as temp dir trees.

## Acceptance

`tests/test_project.lua` covers: Gradle wrapper root from a subproject, Maven `mvnw` root from a submodule,
wrapper-less Gradle (settings file) and Maven (`pom.xml`), no project → `nil`, `module` returns the nearest
submodule, Spring Boot found in a subproject build file, `build/`/`target/`/dot dirs skipped.
