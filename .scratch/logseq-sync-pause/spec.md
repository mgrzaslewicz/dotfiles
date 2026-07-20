# Logseq sync pause — spec

Assembled from a `/grill-me` session. Goal: a way to pause the auto-sync of `~/Logseq` so manual cleanup operations (e.g. an interactive `git rebase`) don't get raced by the scheduled sync job.

## Current state

- `~/Logseq` is auto-synced by [`dot_local/bin/executable_backup.sh.tmpl`](../../dot_local/bin/executable_backup.sh.tmpl): `git add . && git commit && git pull --rebase && git push`.
- Driven by a systemd user timer, [`dot_config/systemd/user/backup.timer`](../../dot_config/systemd/user/backup.timer), firing **every minute**, unconditionally.
- No existing pause/lock mechanism — a manual rebase in `~/Logseq` can be raced by the next minute's auto-commit/pull/push.

## Decisions

1. **Trigger mechanism: a lock file**, not stopping the systemd timer. `~/.logseq-sync.pause`, checked by `backup.sh` immediately before the Logseq-specific git block. Only Logseq syncing is gated — the general directory rsync backups earlier in the script are unaffected.
2. **Auto-recovery: belt and suspenders.** A TTL (see below) *and* session-scoped cleanup, not just one or the other — the user was explicitly worried about forgetting to remove the lock and silently killing sync for an extended period.
3. **TTL: 15 minutes, idle-reset.** Not a flat cap from session start — the deadline is recalculated after each command finishes inside the pause session, so the timeout only ever fires against a lock nobody is actively using (crashed shell, `kill -9`, forgotten terminal), never against an active cleanup session that happens to run long.
4. **Session mechanism: `logseq-pause` drops into a subshell** in `~/Logseq` with the lock held, rather than a single-command wrapper (`logseq-pause -- <cmd>`) — cleanup work is often multi-step/interactive (e.g. `rebase -i`), which doesn't fit a one-shot wrapper.
   - Implemented via zsh's native `TMOUT` idle-timeout, so the shell auto-exits itself after 15 minutes of inactivity — satisfying "the subshell session should stop automatically" without a custom watchdog process.
   - A `precmd` hook re-touches the lock's mtime after every command, which is what makes the TTL idle-based rather than session-start-based.
   - `trap ... EXIT` removes the lock the moment the subshell exits, by any path (manual `exit`/Ctrl-D, or the `TMOUT` timeout firing).
   - The subshell sources the user's real `.zshrc` first (via a throwaway `ZDOTDIR`) so oh-my-zsh, aliases, and prompt all behave normally — only `TMOUT` and the touch hook are layered on top.
5. **Manual escape hatch: `logseq-resume`.** Deletes the lock immediately. Needed because `trap EXIT` doesn't fire on `kill -9`, a crashed terminal, or if the user just wants sync back sooner than the idle timeout.
6. **Notifications: auto-expiry only**, via the existing `notify-send` convention already used for sync errors in `backup.sh`. Manual `logseq-pause`/`logseq-resume` don't notify — the user already knows about actions they just took. Auto-expiry is the one case where sync state changes without the user directly asking, so it's the one case that must surface.
7. **`backup.sh` independently re-checks the lock's age on every run** and clears it if `>= 900s` old, even if the subshell's own `TMOUT`/trap never fired (hard crash, machine sleep). This is the actual "suspenders" half of decision 2 — it also fires the auto-expiry notification.
8. **No pause nesting/reentrancy.** If `logseq-pause` is run while a lock already exists, it refuses and reports the lock's age, rather than taking over or stacking. Two subshells both holding traps on the same lock file is a race — whichever exits first deletes the lock out from under the other. The message points at `logseq-resume` for the stale-lock case.

## Implementation

- [`dot_local/bin/executable_logseq-pause`](../../dot_local/bin/executable_logseq-pause) — refuse-if-locked, hold lock, drop into zsh subshell with idle-timeout + touch hook, cleanup on exit via trap.
- [`dot_local/bin/executable_logseq-resume`](../../dot_local/bin/executable_logseq-resume) — unconditional lock removal.
- [`dot_local/bin/executable_backup.sh.tmpl`](../../dot_local/bin/executable_backup.sh.tmpl) — lock check + TTL backstop gating the existing Logseq git block; everything else in the script (directory rsync, the git logic itself) is unchanged.

The lock path (`~/.logseq-sync.pause`) and TTL (`900` seconds) are duplicated as literals across all three files rather than factored into a shared library — three short standalone scripts didn't seem to justify the extra indirection. Each file has a comment noting the other two must stay in sync if either value changes.
