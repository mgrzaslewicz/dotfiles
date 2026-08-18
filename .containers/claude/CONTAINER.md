# Container Environment

Running in containerized environment.

## Available Tools

- **mise**: Runtime version manager for language toolchains
  - Install runtimes: `mise use <tool>@<version>`
  - List versions: `mise ls-remote <tool>`
  - Examples: `mise use node@20`, `mise use python@3.11`
- **apt-get**: update and install

## Constraints

- **No sudo access**: Only available for `apt-get update` and `apt-get install <package>`
- No tools: docker, podman
- Use mise for language runtimes instead of system package manager

