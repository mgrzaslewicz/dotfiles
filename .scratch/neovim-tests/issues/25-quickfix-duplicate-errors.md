# Compiler errors listed twice in quickfix

Type: task
Status: open
Blocked by: 17

## What

Known limit pinned by the `tasks` cases in `tests/e2e/test_{gradle_java,maven_java,maven_mixed}.lua`: Gradle 9
repeats javac output (indented) under "What went wrong", and Maven repeats javac and kotlin-maven-plugin errors in
its "Failed to execute goal" summary, so every error is in the quickfix list twice. kotlinc errors from Gradle
are listed once.

Options: drop duplicate items (same file, line, column, text) after `on_output_quickfix` sets the list, e.g. a
small overseer component in `custom/plugins/tasks.lua`, tested in `test_tasks.lua` with canned output; or
errorformat rules that skip the summaries (Gradle's indented copy is easy, Maven's copy is identical to the
first). Turn the e2e assertions into "once".
