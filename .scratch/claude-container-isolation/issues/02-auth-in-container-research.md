# Auth/login inside the container without host credentials

Type: research
Status: open

## Question

Today `~/.claude.json` (which holds OAuth session/credentials) is bind-mounted from the host so the container never has to log in. If we stop sharing that file, how does `claude` authenticate inside a `podman run -it --rm` container that has no host browser access and no persisted `~/.claude.json`? Specifically: does Claude Code's OAuth device/browser flow work by printing a URL the user opens on the host (browser not required *inside* the container), or is there a non-interactive path (API key / long-lived token env var) that fits a container better? What, if anything, needs to be captured/persisted (in the new runtime volume) so a user isn't forced to re-auth on every single container start?
