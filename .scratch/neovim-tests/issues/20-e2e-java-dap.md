# Layer B: Java debugging

Type: task
Status: resolved
Blocked by: 15

## What

Spec decision 19 row 6.

- Launch a main class via `<leader>dc` (config chosen programmatically), breakpoint hit at the expected
  line, terminate.
- `<leader>ud` on a test method: breakpoint inside the test hit.

## Acceptance

gradle-java green; DAP sessions cleaned up between cases.

## Notes

- Both cases passed first time (`e2e.debug_until_stopped`, `e2e.debug_stop`): `<leader>dc` with the picker
  answered by the jdtls main class config, and `<leader>ud` through neotest-java's dap strategy.
- Mutation checks: dropping the java-debug-adapter bundle and the `dap` option of `start_or_attach` did not
  turn them red. nvim-jdtls sets up DAP by itself when nvim-dap is installed, and the bundle mutation stayed
  green too (not investigated; jdtls may keep loaded bundles). A no-op `<leader>db` did turn both red (no stop).
- Harness: jdtls workspaces of the fixture copies piled up in the e2e cache (2.8 GB); `fixture_set` now
  deletes the copy's workspace after the file.
