# Remove snap libgomp workaround from git.lua

Type: task
Status: resolved
Blocked by: 01

## What

Spec slice 1 item 8. With daily nvim on mise, the old-glibc libgomp download in `git.lua` is dead code.

- Delete the snap branch; keep "codediff failing doesn't abort startup".
- Test-first: smoke test that loading `git.lua` with codediff unavailable leaves Neogit usable and startup error-free.

## Acceptance

No `snap` references remain in `dot_config/nvim/`; test green.

## Notes

- codediff itself downloads a bundled libgomp when the system has none (seen in the test container:
  "System libgomp.so.1 not found, downloading..."). Check whether that fallback also covers the snap case
  before deleting, and whether `git.lua`'s own download is redundant regardless of snap.
- Checked: codediff downloads its own libgomp only when `ldconfig` finds none (or on Nix). Under snap the host
  libgomp exists but needs a newer glibc than core22, so codediff's fallback never covered snap; `git.lua`'s
  download was snap-only and is dead with mise nvim (host glibc). Under snap, codediff now fails and is disabled
  with a warning (Neogit keeps working).
- `tests/test_git.lua`: a failing native library (injected as `codediff.core.diff`, where `ffi.load` happens)
  leaves startup error-free, `:Neogit` available, codediff integration off, warning shown; without the failure
  codediff is the diff viewer. Mutation: dropping the `pcall` fails the first case.
- `INTELLIJ_TRANSITION.md` snap item and log line updated/removed ahead of issue 12.
