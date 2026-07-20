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

## Not yet specified

## Out of scope
