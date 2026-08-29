# Container Environment

Running in containerized environment.

## Available Tools

- **mise**: Runtime version manager for language toolchains
  - Install runtimes: `mise use <tool>@<version>`
  - List versions: `mise ls-remote <tool>`
  - Examples: `mise use node@20`, `mise use python@3.11`
- **apt-get**: update and install
- **podman** / **podman-compose**: rootless-in-rootless, with a real gap right now:
  - **Pulling and inspecting images works** (`podman pull`, `podman images`, etc.)
  - **Running a container, or a Dockerfile `RUN` step, currently fails** — every attempt hits `crun: open /proc/sys/net/ipv4/ping_group_range: Read-only file system` at container start, before your command even runs. Root cause: the host's `runc` fails to write network sysctls via its newer `fsconfig()`-based mount setup — a host runtime bug, not something fixable from inside this container or via `podman run` flags (extensively tried — see `dot_local/bin/executable_claude` and `dot_oh-my-zsh/custom/executable_claude.zsh` git history for what was ruled out). Fix is pending a `runc` update on the host.
  - Storage is ephemeral: wiped every container restart, nothing persists across sessions
  - Public registries only (docker.io, ghcr.io, quay.io, etc.) — no private registry credentials are configured
  - Single-identity mapping only (no subuid range, no newuidmap): once running containers work again, a container you run here won't get its own separate root user — its "root" is just this same claude-user identity. Fine for a normal build/run/test cycle; a Dockerfile that relies on `USER` switching to a genuinely different uid, or that needs many distinct uids, won't work as expected.

## Constraints

- **No sudo access**: Only available for `apt-get update` and `apt-get install <package>`
- No tool: docker
- Use mise for language runtimes instead of system package manager

