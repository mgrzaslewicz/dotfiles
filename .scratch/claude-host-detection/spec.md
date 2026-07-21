# Host-detectable claude for claude-toolbox — spec

Assembled from the resolved [map](map.md) tickets. Goal: let host tools that
spawn `claude` as a subprocess (OpenClaw and similar) find and use it, when
the only "claude" on this machine lives inside the `claude-toolbox` podman
container.

## Root cause

`claude-toolbox()` is a zsh shell function. Shell functions only exist inside
the interactive zsh session that defines them — they are invisible to
`execvp`/`which`/`command -v` lookups done by any other process, including
other tools' subprocess spawns. OpenClaw's Claude Code backend specifically
runs `claude -p` (non-interactive print mode, piped stdin/stdout) and detects
Claude Code by finding a real `claude` binary on `PATH`. No amount of zsh
aliasing fixes that; it needs a real file on disk.

## 1. New file: `dot_local/bin/executable_claude`

Chezmoi-managed, deploys to `~/.local/bin/claude` (executable). A bash script
that:

- Auto-detects TTY attachment (`[ -t 0 ] && [ -t 1 ]`) to choose `-it` vs `-i`
  for `podman run`, so it works both for a human typing `claude` directly and
  for a tool piping stdin/stdout non-interactively.
- Auto-builds `claude-toolbox:latest` if missing, with the same
  `--build-arg USER_ID`/`GROUP_ID` as `claude-toolbox()`.
- Creates (idempotently) and mounts the same three global podman volumes
  `claude-toolbox()` uses (`claude-toolbox-config`, `claude-toolbox-config-json`,
  `claude-toolbox-mise`) — shared credentials/tool state between interactive
  and automated use.
- Mounts the working directory at its **identical absolute host path**
  (`-v "$PWD:$PWD:rw" --workdir "$PWD"`), unlike `claude-toolbox()`'s
  `/workspace/$(basename "$PWD")` scheme — so any file paths a caller reads
  back out of claude's output (edits, diffs, tool calls) match real host
  paths.
- Does **not** forward any host environment variables (no `ANTHROPIC_API_KEY`/
  `CLAUDE_CODE_OAUTH_TOKEN` passthrough) — auth relies solely on the
  credentials already persisted in the volume from a one-time interactive
  login via `claude-toolbox()`.
- Does **not** self-guard against a real, natively-installed `claude` —
  relies on `~/.local/bin` being ordered after any native-install location in
  the host's `PATH` (user-verified fact, not enforced by the script).
- Produces no output of its own (no banners/notices) — stdout, stderr, and
  exit code are exactly the containerized `claude`'s, so it's indistinguishable
  from a native install to a calling tool.
- Invokes the container's setup script explicitly, not `claude` directly (see
  §2), forwarding all wrapper args through to it:

```bash
exec podman run \
    --rm \
    "$TTY_FLAG" \
    --userns=keep-id \
    -v "$PWD:$PWD:rw" \
    -v "${VOLUME_NAME}:/home/claude-user/.claude:rw" \
    -v "${VOLUME_JSON_NAME}:/home/claude-user/.claude-json-dir:rw" \
    -v "${VOLUME_MISE_NAME}:/opt/mise:rw" \
    --workdir "$PWD" \
    --env TERM="${TERM:-xterm-256color}" \
    "$IMAGE_NAME" \
    /home/claude-user/setup-and-run-claude.sh "$@"
```

Kept fully independent from `dot_oh-my-zsh/custom/executable_claude.zsh`
(`claude-toolbox()`) — no shared script/logic extraction. The two live in
different runtimes (zsh function vs. real host executable) and now diverge
on TTY handling and mount scheme; sharing across that boundary was judged not
worth the indirection for the amount of code saved.

## 2. One-line change: `.containers/claude/setup-and-run-claude.sh`

Passing `claude-toolbox:latest claude "$@"` as a `podman run` command
override replaces the image's `CMD` entirely, so `setup-and-run-claude.sh`
(and its credentials symlink, `mise reshim`, plugin/settings reconciliation,
codegraph sync, rtk hook install) would never run. Fixed by having the
wrapper name the setup script itself as the command, forwarding args through
it, and changing the script's final line:

```bash
# before
claude

# after
exec claude "$@"
```

`"$@"` is empty for `claude-toolbox()`'s existing invocation (it never
overrides the podman command), so this is a no-op there — fully backward
compatible with the current interactive flow.

## 3. Unchanged

- `dot_oh-my-zsh/custom/executable_claude.zsh` (`claude-toolbox()`,
  `claude-toolbox-new()`, `claude-toolbox-reset()`,
  `claude-toolbox-reset-tools()`) — no changes.
- `.containers/claude/Dockerfile` — no changes.

## Verification note

PATH ordering (whether `~/.local/bin` resolves after any native-install
location, so a real `claude` would take precedence if one is ever installed)
was confirmed by the user on the actual host; this repo/session has no way to
inspect that directly.
