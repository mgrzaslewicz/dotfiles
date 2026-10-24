# Layer B: Java debugging

Type: task
Status: open
Blocked by: 15

## What

Spec decision 19 row 6.

- Launch a main class via `<leader>dc` (config chosen programmatically), breakpoint hit at the expected
  line, terminate.
- `<leader>ud` on a test method: breakpoint inside the test hit.

## Acceptance

gradle-java green; DAP sessions cleaned up between cases.
