# Host-detectable claude for claude-toolbox

## Destination

Make `claude-toolbox` detectable by host tools that spawn a `claude` subprocess
(e.g. OpenClaw, which runs `claude -p ...` non-interactively and finds it by
locating a `claude` binary on `PATH`), when no native `claude` is installed on
the host. Hand-off targets: new `dot_local/bin/executable_claude` (host-PATH
wrapper), `.containers/claude/setup-and-run-claude.sh` (one-line change).

## Notes

- Domain: same claude-toolbox podman setup covered by
  `../claude-container-isolation/`, extended to make it usable by non-human,
  non-interactive callers on the host.
- Current state (facts, not decisions):
  - `claude-toolbox()` (`dot_oh-my-zsh/custom/executable_claude.zsh`) is a
    **zsh function**, not a file on `PATH`. Anything that resolves `claude`
    via `execvp`/`which` outside an interactive zsh session (i.e. any
    subprocess-spawning tool) cannot see it at all — this is the root cause,
    not a detection-logic bug in those tools.
  - OpenClaw's Claude Code backend runs `claude -p` in non-interactive print
    mode with piped stdin/stdout, and detects Claude Code by finding a
    `claude` binary on `PATH` (confirmed via web search, see spec.md).
  - The container's `CMD` is `setup-and-run-claude.sh`, which does one-time-ish
    idempotent init (credentials symlink for `~/.claude.json`, `mise reshim`,
    plugin/settings reconciliation, statusline badge, rtk hook install,
    codegraph install/sync) and, before this change, ended with a bare
    `claude` with no arg forwarding. Passing `claude "$@"` as a podman command
    override replaces `CMD` entirely, skipping that init — found while
    designing the wrapper, not previously documented.
  - `claude-toolbox()` mounts `$PWD` at `/workspace/$(basename "$PWD")` inside
    the container — only the last path component, not the full host path.
- Consult `/grilling` for decision tickets (this session's transcript).

## Decisions so far

- [Overall approach](issues/01-approach.md) — a real host-PATH wrapper script
  (`~/.local/bin/claude`) that forwards to the container via `podman run`,
  not a native install.
- [Guarding against a real claude install](issues/02-shadow-guard.md) — none
  in the script; rely on `~/.local/bin` being ordered after any native-install
  location in the host's `PATH` (confirmed by user).
- [Interactive vs non-interactive support](issues/03-tty-handling.md) — both,
  auto-detected via `[ -t 0 ] && [ -t 1 ]`, choosing `-it` vs `-i` for podman.
- [Path mounting scheme](issues/04-path-mounting.md) — mount `$PWD` at the
  identical absolute host path, not the basename-only scheme
  `claude-toolbox()` uses, so paths in claude's output match host paths.
- [Env var passthrough](issues/05-env-passthrough.md) — none; auth relies
  solely on the credentials already persisted in the volume.
- [Code sharing with claude-toolbox()](issues/06-code-sharing.md) — kept
  independent; some duplication accepted rather than extracting shared
  podman-invocation logic across the zsh-function/host-script boundary.
- [Missing image handling](issues/07-missing-image.md) — auto-build,
  matching `claude-toolbox()`'s existing behavior.
- [Running init on every call](issues/08-init-on-every-call.md) — the wrapper
  invokes the container's `setup-and-run-claude.sh` explicitly (rather than
  `claude` directly) so its init still runs before every call; the script's
  final line changed from `claude` to `exec claude "$@"` to forward args
  through after init completes. No-op for `claude-toolbox()`'s existing
  no-args invocation.
- [PATH order verification](issues/09-path-order-verification.md) — user
  confirmed `~/.local/bin` already resolves after native-install locations on
  their host `PATH`.
- [Wrapper verbosity](issues/10-wrapper-verbosity.md) — completely silent;
  stdout/stderr/exit code are exactly the containerized claude's.

All tickets resolved — the destination is reached. See `spec.md` for the
assembled hand-off spec.

## Not yet specified

## Out of scope

- Refactoring `claude-toolbox()` itself, or extracting shared podman logic
  (see [issues/06-code-sharing.md](issues/06-code-sharing.md)).
- Verifying the actual host `PATH` order beyond the user's own confirmation
  (this repo/session has no access to the real host shell environment).
