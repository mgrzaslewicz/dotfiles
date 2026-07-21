# Overall approach

Type: grilling
Status: resolved

## Question

`claude-toolbox` is currently a zsh shell function
(`dot_oh-my-zsh/custom/executable_claude.zsh`), invisible to any process that
resolves `claude` via `execvp`/`which` outside an interactive zsh session —
which is exactly how tools like OpenClaw look for it (they spawn
`claude -p ...` as a subprocess). Given no real `claude` should be installed
on the host, what should make it detectable?

## Answer

A real host-side wrapper script at `~/.local/bin/claude` that forwards
invocations into the `claude-toolbox` container via `podman run`. Since it's
a real file on `PATH`, `which claude` / `command -v claude` / subprocess
spawns all resolve to it, unlike the zsh function.
