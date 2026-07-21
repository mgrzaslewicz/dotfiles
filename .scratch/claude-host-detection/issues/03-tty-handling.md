# Interactive vs non-interactive support

Type: grilling
Status: resolved

## Question

OpenClaw runs `claude -p` non-interactively with piped stdin/stdout, which
breaks if `podman run` is forced into `-it` (requires a real TTY). Should the
new wrapper support only that non-interactive mode, leaving interactive
human use to the existing `claude-toolbox()` function, or auto-detect and
support both?

## Answer

Both, auto-detected: `[ -t 0 ] && [ -t 1 ]` decides whether to pass `-it` or
just `-i` to `podman run`. Makes `claude` behave correctly whether a human
runs it directly at a terminal or a tool pipes into it, mirroring how the
real `claude` binary behaves either way.
