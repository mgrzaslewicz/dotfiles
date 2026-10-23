# Remove snap libgomp workaround from git.lua

Type: task
Status: open
Blocked by: 01

## What

Spec slice 1 item 8. With daily nvim on mise, the old-glibc libgomp download in `git.lua` is dead code.

- Delete the snap branch; keep "codediff failing doesn't abort startup".
- Test-first: smoke test that loading `git.lua` with codediff unavailable leaves Neogit usable and startup error-free.

## Acceptance

No `snap` references remain in `dot_config/nvim/`; test green.
