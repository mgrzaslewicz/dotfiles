# Claude Code auth inside an isolated container

Research for redesigning the podman container setup to run `claude` fully
isolated from the host (no bind-mounted `~/.claude.json`), launched via
`podman run -it --rm --userns=keep-id` against a headless `debian:13` image
with no browser installed.

Primary sources consulted: `claude --help` / `claude auth --help` /
`claude setup-token --help` output on this host (Claude Code v2.1.205), the
official docs at `code.claude.com/docs/en/authentication` (the
`docs.claude.com/.../iam` and `.../cli-reference` URLs both 301-redirect to
`code.claude.com`), and this host's own `~/.claude/` directory contents.

## 1. What does the login flow actually do with no `~/.claude.json`?

On first launch (`claude` with no stored credentials), Claude Code **tries
to open a local browser window automatically**, and falls back to a
copy/paste URL flow — it does not require a browser inside the process
itself:

> "After installing Claude Code, run `claude` in your terminal. On first
> launch, Claude Code opens a browser window for you to log in. If the
> browser doesn't open automatically, press `c` to copy the login URL to
> your clipboard, then paste it into your browser."
>
> "If your browser shows a login code instead of redirecting back after you
> sign in, paste it into the terminal at the `Paste code here if prompted`
> prompt. This happens when the browser can't reach Claude Code's local
> callback server, which is common in WSL2, SSH sessions, and containers."
>
> — [code.claude.com/docs/en/authentication](https://code.claude.com/docs/en/authentication), "Log in to Claude Code"

Implication for our container: since debian:13 has no browser, the
automatic-open attempt is a no-op, but the CLI still surfaces a URL (via the
`c`-to-copy affordance) meant to be opened on a **separate machine's**
browser — the user's own laptop, not anything inside the container. Because
the container can't run a local callback server reachable from an external
browser, the flow lands in the documented fallback path: the external
browser shows a **login code** that the user pastes back into the
container's terminal (`Paste code here if prompted`). This is explicitly
called out as "common in ... containers", i.e. Anthropic designed for
exactly this topology. No browser is ever required inside the container
process.

`claude auth login` (an `auth login` subcommand also exists per
`claude auth --help` on this host: `Sign in to your Anthropic account`) is
the same flow, invocable directly instead of relying on first-run
auto-trigger; the CLI reference documents `--email`, `--sso`, and
`--console` flags for it.

## 2. Non-interactive/headless auth path

Yes — two independent tiers:

**a) Fully non-interactive, no OAuth dance at all**: set `ANTHROPIC_API_KEY`
(sent as `X-Api-Key`) or `ANTHROPIC_AUTH_TOKEN` (sent as
`Authorization: Bearer`, for gateway/proxy setups), or configure an
`apiKeyHelper` script setting that returns a key. In non-interactive mode
(`-p`) an `ANTHROPIC_API_KEY` is always used when present — no prompt at
all. Source: [code.claude.com/docs/en/authentication](https://code.claude.com/docs/en/authentication), "Credential management" / "Authentication precedence".

**b) Long-lived OAuth token bootstrapped once outside the container,
consumed headlessly thereafter**: `claude setup-token` (confirmed present
via `claude --help` → `setup-token: Set up a long-lived authentication
token (requires Claude subscription)`):

> "For CI pipelines, scripts, or other environments where interactive
> browser login isn't available, generate a one-year OAuth token with
> `claude setup-token`... The command opens the same browser authorization
> flow as `/login`, and the token prints to the terminal after you approve
> access in the browser. It does not save the token anywhere; copy it and
> set it as the `CLAUDE_CODE_OAUTH_TOKEN` environment variable wherever you
> want to authenticate."
>
> — [code.claude.com/docs/en/authentication](https://code.claude.com/docs/en/authentication), "Generate a long-lived token"

So `setup-token` still requires one interactive browser approval
somewhere (can be run once on a host with a browser, or via the same
copy-URL/paste-code fallback as `/login`), but the **output is a token
string**, not a file — the operator copies it and exports it as
`CLAUDE_CODE_OAUTH_TOKEN` in the container's environment on every run. This
is the cleanest fit for a fully isolated, no-persisted-credential-file
container: mint the token once outside/alongside the container, inject it
as an env var (e.g. via podman `--env` or a secrets file), and skip
persisting any `~/.claude` state at all for auth purposes. Caveats
documented on the same page: this token is subscription-tier (Pro/Max/
Team/Enterprise) only, can't establish Remote Control sessions or fetch
claude.ai connectors, and is **not read in `--bare` mode** (bare mode only
accepts `ANTHROPIC_API_KEY` or `apiKeyHelper`).

Authentication precedence when several are present (highest first): cloud
provider env vars (Bedrock/Vertex/Foundry) → `ANTHROPIC_AUTH_TOKEN` →
`ANTHROPIC_API_KEY` → `apiKeyHelper` output → `CLAUDE_CODE_OAUTH_TOKEN` →
subscription OAuth from `/login`. Source: same page, "Authentication
precedence".

## 3. What files hold credential/session state after authenticating via `/login`?

Per official docs, **credential storage is OS-dependent**:

> "On macOS, credentials are stored in the encrypted macOS Keychain. On
> Linux, credentials are stored in `~/.claude/.credentials.json` with file
> mode `0600`. On Windows, credentials are stored in
> `%USERPROFILE%\.claude\.credentials.json`... If you've set the
> `CLAUDE_CONFIG_DIR` environment variable on Linux or Windows, the
> `.credentials.json` file lives under that directory instead."
>
> — [code.claude.com/docs/en/authentication](https://code.claude.com/docs/en/authentication), "Credential management"

Since the target container is `debian:13` (Linux), the relevant file is
**`~/.claude/.credentials.json`** (or `$CLAUDE_CONFIG_DIR/.credentials.json`
if that env var is set) — this is the file that must survive across
container restarts to avoid re-running `/login` every time.

Inspecting this host's own `~/.claude/.credentials.json` (macOS also had a
Keychain entry named `Claude Code-credentials`, but the file exists here
too) shows its top-level JSON structure — field *names* only, no values:

- `claudeAiOauth` (object): `accessToken`, `refreshToken`, `expiresAt`,
  `refreshTokenExpiresAt`, `scopes`, `subscriptionType`, `rateLimitTier`
  — this is the actual Claude.ai/subscription OAuth session.
- `mcpOAuth` (object, keyed per configured MCP server): each entry has
  `serverName`, `serverUrl`, `accessToken`, `clientId`, `redirectUri`,
  `discoveryState` (`authorizationServerUrl`, `resourceMetadataUrl`,
  `oauthMetadataFound`), and sometimes `clientSecret` — these are separate
  OAuth sessions for any MCP servers configured to use OAuth (e.g. Jira/
  Confluence, GitLab connectors), independent of the core Claude Code login.

By contrast, `~/.claude.json` (on this host a symlink to
`~/.claude/.claude.json`, likely due to a dotfiles/chezmoi setup — not
necessarily true of a stock install) holds **non-secret** state: analytics/
telemetry counters, onboarding flags, per-project trust-dialog acceptance,
MCP server *configuration* (not their tokens), and an `oauthAccount` object
whose fields are all profile metadata — `accountUuid`, `emailAddress`,
`organizationUuid`, `billingType`, `organizationName`, `seatTier`,
`organizationRole`, etc. — no `accessToken`/`refreshToken` fields were
found in this file. The docs corroborate the split: "Claude Code manages
`.credentials.json` through `/login` and `/logout`" — i.e. that's the
credential file the CLI actively writes on auth events, distinct from the
general config/state file.

### Bottom line for the container redesign

- **Minimum required for persistence to avoid re-auth every start (Linux
  container):** `~/.claude/.credentials.json` (respecting `$CLAUDE_CONFIG_DIR`
  if set). Mount only this file (or the whole `~/.claude/` dir if simplicity
  is preferred) into a runtime-only volume, not the host's real `~/.claude`.
- **Not required for auth, but affects UX** (re-triggers trust dialogs /
  onboarding, not re-auth) if not persisted: `~/.claude.json` /
  `~/.claude/.claude.json`.
- **Recommended alternative that needs no persisted file at all:** mint a
  `CLAUDE_CODE_OAUTH_TOKEN` once (via `claude setup-token`, run interactively
  a single time, possibly outside the container or through the copy-URL/
  paste-code fallback) and inject it into the container's environment on
  every run (e.g. podman `--env CLAUDE_CODE_OAUTH_TOKEN=...` sourced from a
  secret store) — this keeps the container's filesystem fully ephemeral and
  ephemeral-container-friendly, at the cost of losing Remote Control/claude.ai
  connector features and needing periodic (≈yearly) token renewal.
- If MCP servers using OAuth are configured inside the container, their
  tokens live in the same `.credentials.json` under `mcpOAuth`, so that file
  covers both concerns together.
