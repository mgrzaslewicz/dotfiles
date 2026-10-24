# Layer B: codediff native library and diff view

Type: task
Status: open
Blocked by: 15

## What

Spec decision 19 row 9.

- Fresh e2e root: codediff downloads its library on first use; open a diff of a changed file in a temp
  git repo; assert the diff view's windows/buffers.

## Acceptance

Green from a fresh `tests/.tests-e2e`.
