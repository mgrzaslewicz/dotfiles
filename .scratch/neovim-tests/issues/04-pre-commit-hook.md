# Pre-commit hook for nvim changes, `mise run setup`

Type: task
Status: resolved
Blocked by: 03

## What

Spec decision 10.

- `.githooks/pre-commit` (bash):
  - exit 0 if `git diff --cached --name-only -- dot_config/nvim/` is empty;
  - else set aside unstaged changes (patch) and untracked files (tar) in a per-run dir under the
    worktree's git dir, reset the working tree to the index, run `mise run check`, restore via `trap`.
- `mise run setup`: `git config core.hooksPath .githooks` (repo-local, idempotent). Never global.

## Acceptance

- Commit touching only non-nvim paths: hook does not run the check.
- Commit with a failing nvim test: rejected.
- Partially staged file where only the unstaged part fixes a test: rejected; working tree restored byte-for-byte.
- Hook interrupted (Ctrl-C) mid-check: working tree restored.
- Works from a second worktree without re-running setup.

## Notes

Verified in a scratch repo (git does not work in the dev container's worktree): non-nvim commit skips (~10 ms),
failing test rejects, partial staging checked as staged with working tree + index restored, passing commit keeps
unstaged and untracked changes, Ctrl-C restores immediately, fresh worktree works without setup (bootstraps
plugins inside the hook, ~7 s), concurrent commits in two worktrees keep their own changes.

Bugs found and fixed on the way:
- `git stash` is shared by all worktrees: concurrent hooks popped each other's stash. Replaced by a private backup.
- Hooks export `GIT_INDEX_FILE` & co.; plugin clones during the first bootstrap inherited them and ended up
  empty. `run.sh` unsets `git rev-parse --local-env-vars`.
- A Lua error before tests start left headless nvim running forever (hook hung). `minimal_init.lua` and the
  `run.sh` entry point turn errors into `cquit 1`; the bootstrap check looks for `mini/test.lua`, not the dir.
- Headless nvim and lua-language-server ignore SIGINT: Ctrl-C kept the check running ~15 s with the working tree
  reset. `run.sh` and `check:types` forward INT/TERM as SIGTERM. (A runner blocking its own event loop, e.g.
  `vim.uv.sleep` in the runner process, still ignores SIGTERM; tests must not do that.)
- `vim.loader` cache file names embed the full escaped path of each plugin file: a checkout path of ~130+
  chars fails with ENAMETOOLONG. Not fixed; keep the repo at a normal-length path.
