# Layer B: session restore

Type: task
Status: resolved
Blocked by: 15

## What

Spec decision 19 row 8.

- In gradle-java: open files in splits plus panels (neo-tree, quickfix), quit, start a new child in the
  same cwd; assert buffers/splits restored, jdtls attached, no empty panel windows.

## Acceptance

gradle-java green.

## Notes

- Passed first time: two splits restored, jdtls attached at the build root, no panel windows (neo-tree and
  quickfix were open at exit). Quits with `qall!` (mini.test's stop uses `0cquit`).
- Mutation checks: disabling the PersistenceSavePre panel cleanup alone stays green, because `sessionoptions`
  without `blank` already keeps panels out of the session; adding `blank` too turns it red (an empty window and
  a neo-tree window come back). The cleanup is a second line of defence.
- The case stops the shared child first (two jdtls on one workspace conflict); `fixture_set` copes with that.
- The test listed restored windows with `vim.fs.relpath`, which is nil for an empty window, so an empty panel
  went unnoticed at first; empty windows are now listed explicitly.
