# Volume granularity: global vs per-project

Type: grilling
Status: resolved

## Question

`claude-toolbox` today is invoked from any `$PWD` and shares one host `~/.claude` across every project. Once settings move to a container-only volume, should there still be one global volume shared across all projects run through `claude-toolbox`, or one volume per project/repo? This affects whether switching projects carries over plugin state, conversation history, and project memory, or isolates them.

## Answer

One global volume — preserves today's behavior (host `~/.claude` is already shared across all projects), keeps a single set of credentials, and avoids duplicating the plugin cache/marketplace clones per project. A single fixed-name podman volume (e.g. `claude-toolbox-config`) mounted at `~/.claude`/`~/.claude.json`, replacing the current host bind-mount in `claude-toolbox()`.
