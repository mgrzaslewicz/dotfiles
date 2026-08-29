# Container Environment

Running in containerized environment.

## Available Tools

- **mise**: Runtime version manager for language toolchains
  - Install runtimes: `mise use <tool>@<version>`
  - List versions: `mise ls-remote <tool>`
  - Examples: `mise use node@20`, `mise use python@3.11`
- **apt-get**: update and install
- **podman** / **podman-compose**: build, run, and test containers (rootless-in-rootless)
  - Storage is ephemeral: wiped every container restart, nothing persists across sessions
  - Public registries only (docker.io, ghcr.io, quay.io, etc.) — no private registry credentials are configured
  - Single-identity mapping only (no subuid range, no newuidmap): a container you run here doesn't get its own separate root user — its "root" is just this same claude-user identity. Fine for a normal build/run/test cycle; a Dockerfile that relies on `USER` switching to a genuinely different uid, or that needs many distinct uids, won't work as expected.

## Constraints

- **No sudo access**: Only available for `apt-get update` and `apt-get install <package>`
- No tool: docker
- Use mise for language runtimes instead of system package manager

