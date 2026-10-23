# Pre-commit hook for nvim changes, `mise run setup`

Type: task
Status: open
Blocked by: 03

## What

Spec decision 10.

- `.githooks/pre-commit` (bash):
  - exit 0 if `git diff --cached --name-only -- dot_config/nvim/` is empty;
  - else stash unstaged + untracked (`git stash push --keep-index --include-untracked`),
    restore with a `trap` on any exit, run `mise run check`.
- `mise run setup`: `git config core.hooksPath .githooks` (repo-local, idempotent). Never global.

## Acceptance

- Commit touching only non-nvim paths: hook does not run the check.
- Commit with a failing nvim test: rejected.
- Partially staged file where only the unstaged part fixes a test: rejected; working tree restored byte-for-byte.
- Hook interrupted (Ctrl-C) mid-check: working tree restored.
- Works from a second worktree without re-running setup.
