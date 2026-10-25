# Layer B: codediff native library and diff view

Type: task
Status: resolved
Blocked by: 15

## What

Spec decision 19 row 9.

- Fresh e2e root: codediff downloads its library on first use; open a diff of a changed file in a temp
  git repo; assert the diff view's windows/buffers.

## Acceptance

Green from a fresh `tests/.tests-e2e`.

## Notes

- `tests/e2e/test_codediff.lua`: deletes codediff's library from the e2e plugin dir (first use without wiping
  the whole e2e root), starts nvim in a temp git repo, waits for the download (it finishes after startup),
  then `<leader>gd`: a new tab with the explorer, the HEAD version and the working file.
- Passed first time; mutation: Neogit without codediff as diff viewer turns it red.
- codediff also downloads `codediff-watcher` on first use.
