# Env var passthrough

Type: grilling
Status: resolved

## Question

Should the wrapper forward any host environment variables into the
container invocation (e.g. `ANTHROPIC_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`),
in case OpenClaw or another caller sets them expecting the `claude`
subprocess to pick them up — or rely purely on the credentials already
persisted in the volume from the one-time interactive login?

## Answer

No passthrough. Auth relies solely on the credentials already persisted in
`claude-toolbox-config`/`claude-toolbox-config-json` from the existing
interactive login flow (see
`../claude-container-isolation/issues/02-auth-in-container-research.md`).
