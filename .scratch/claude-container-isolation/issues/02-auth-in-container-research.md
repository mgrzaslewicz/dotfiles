# Auth/login inside the container without host credentials

Type: research
Status: resolved

## Question

Today `~/.claude.json` (which holds OAuth session/credentials) is bind-mounted from the host so the container never has to log in. If we stop sharing that file, how does `claude` authenticate inside a `podman run -it --rm` container that has no host browser access and no persisted `~/.claude.json`? Specifically: does Claude Code's OAuth device/browser flow work by printing a URL the user opens on the host (browser not required *inside* the container), or is there a non-interactive path (API key / long-lived token env var) that fits a container better? What, if anything, needs to be captured/persisted (in the new runtime volume) so a user isn't forced to re-auth on every single container start?

## Answer

Full findings: [`research/auth-in-container.md`](research/auth-in-container.md).

1. **Login flow needs no browser inside the container.** `claude` tries to auto-open a browser but always falls back to a copy-URL + paste-code-back-into-terminal flow, which Anthropic's own docs call out as the path for WSL2/SSH/containers. The user opens the URL on their own machine and pastes the code into the container's TTY. Source: `code.claude.com/docs/en/authentication`.
2. **Two non-interactive tiers exist**: fully headless via `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` / an `apiKeyHelper` script (no OAuth at all); or `claude setup-token`, which mints a one-year OAuth token via a single interactive approval (can be done once, outside the container) and is meant to be exported as `CLAUDE_CODE_OAUTH_TOKEN` (not honored in `--bare` mode).
3. **Credential files, minimum to persist**: the actual secrets live in `~/.claude/.credentials.json` (mode 0600, a `claudeAiOauth` object plus per-MCP-server `mcpOAuth` entries) — this respects `$CLAUDE_CONFIG_DIR` if set. `~/.claude.json` holds no secrets, only onboarding/trust-dialog/profile state. So the minimum needed in a runtime-only volume to avoid re-auth every start is just `~/.claude/.credentials.json`; the cleanest container-native alternative is skipping file persistence entirely and injecting `CLAUDE_CODE_OAUTH_TOKEN` as an env var each run.
