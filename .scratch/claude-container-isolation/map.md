# Claude container settings isolation

## Destination

A spec for fully disconnecting the Claude container's settings (`~/.claude`, `~/.claude.json`) from the host — replacing the current bind-mount (`dot_oh-my-zsh/custom/executable_claude.zsh`) with a container-only persistent volume, re-authenticating inside the container instead of sharing host credentials. The spec covers volume layout, how build-time-baked plugins/skills (installed in `.containers/claude/Dockerfile`) survive a persistent runtime volume without being shadowed, and the reset/rebuild workflow. Hand-off targets: `.containers/claude/Dockerfile`, `.containers/claude/setup-and-run-claude.sh`, and the `claude-toolbox` / `claude-toolbox-new` zsh functions.

## Notes

- Domain: devcontainer/podman tooling for running Claude Code in an isolated environment, part of this dotfiles repo.
- Current state (facts, not decisions):
  - Build time: Dockerfile installs Claude via mise, installs the `mattpocock-skills` plugin, bakes `HOME=/home/claude-user`, `XDG_CONFIG_HOME=/home/claude-user/.config`.
  - Run time: `claude-toolbox()` bind-mounts host `~/.claude` → `/home/claude-user/.claude` and host `~/.claude.json` into the container, using `podman run --userns=keep-id --rm`.
  - The host bind-mount shadows whatever was baked into the image at `/home/claude-user/.claude` at build time — this is the trade-off driving this effort.
- Consult `/grilling` and `/domain-modeling` for decision tickets; `/research` for research tickets.

## Decisions so far

- [Auth/login inside the container without host credentials](issues/02-auth-in-container-research.md) — no browser needed inside the container (paste-code fallback); `CLAUDE_CODE_OAUTH_TOKEN` env var or `~/.claude/.credentials.json` alone is enough to avoid re-auth, `~/.claude.json` holds no secrets.
- [Claude Code config layout & plugin shadowing](issues/01-config-layout-research.md) — the undocumented-but-real `CLAUDE_CONFIG_DIR` env var lets build-time-baked plugins live outside `$HOME`, physically separate from a runtime volume mounted over `~/.claude`; no merge/reconciliation is possible or needed once separated this way.
- [Reconciliation strategy for build-time bake vs runtime volume](issues/04-reconciliation-strategy.md) — bake plugins at build time via `CLAUDE_CONFIG_DIR=/opt/claude-config-baked`; entrypoint symlinks `~/.claude/plugins` to it and `jq`-merges just the plugin-registration keys into the volume-backed `~/.claude/settings.json` on every start. Runtime state (session history, project memory, MCP trust state) stays live/volume-backed.
- [Volume granularity: global vs per-project](issues/03-volume-granularity.md) — one global named volume (e.g. `claude-toolbox-config`) shared across all projects, matching today's behavior; avoids duplicating credentials/plugin cache per project.
- [Reset/rebuild UX for the volume](issues/05-reset-rebuild-ux.md) — separate `claude-toolbox-reset` (wipes the volume) from `claude-toolbox-new` (rebuilds the image); the two concerns are independent since plugin freshness no longer needs a wipe.

## Not yet specified

## Out of scope
