# Claude Code config layout & plugin shadowing

Type: research
Status: resolved

## Question

How does Claude Code lay out its config under `~/.claude` / `$XDG_CONFIG_HOME` (plugins, marketplaces, skills, MCP config, session history, project memory)? Is there a system-wide or non-`$HOME` location plugins/skills can be installed to (e.g. a directory Claude Code reads in addition to the user config dir) so that build-time-baked plugins aren't shadowed by a runtime volume mounted over the user config dir? If no such separate location exists, what does Claude Code's own precedence/merge behavior look like when both a system config and a user config are present?

This answer determines whether ticket 04 (reconciliation strategy) can rely on physical separation (bake outside the volume path) versus needing an explicit merge/sync step.

## Answer

Full findings: [`research/config-layout.md`](research/config-layout.md).

1. **What's under `~/.claude`**: `settings.json` (permissions/hooks/theme/enabledPlugins/marketplaces), the plugin system (`plugins/cache` = installed plugin code, `plugins/marketplaces` = cloned marketplace repos, `plugins/data` = persistent plugin data, `skills/` = personal skills-directory plugins), session transcripts (`projects/<path>/*.jsonl`), prompt history, user `CLAUDE.md`, credentials (`.credentials.json` or Keychain), daemon/cache/telemetry state. MCP servers and per-project trust state live in `~/.claude.json`, not `settings.json`. Project-scope settings/skills/MCP config live in the project directory (`.claude/settings.json`, `.mcp.json`), not under home.
2. **Yes — `CLAUDE_CONFIG_DIR` exists and does the job.** Undocumented (absent from `--help` and the official env-vars page) but real — confirmed empirically: setting it redirects the entire config tree (`settings.json`, `.claude.json`, `plugins/cache`, `plugins/marketplaces`, etc.) to an arbitrary path; the real `~/.claude` stays untouched. Corroborated by two open `anthropics/claude-code` GitHub issues (#25762, #33430). `--scope project`/`local` for `plugin install` only redirects the settings-file *reference*, not the plugin cache, so it doesn't solve this alone.
3. **No merge — wholesale shadowing.** Claude Code's scope-precedence system (managed > CLI > local > project > user) only arbitrates between genuinely different file paths. A volume mounted over `~/.claude` isn't two Claude Code scopes competing — it's the OS replacing the whole directory tree beneath Claude Code's own logic. The only fix is keeping build-time content off the mounted path entirely.

**Recommendation for ticket 04**: bake plugins/skills at build time under `CLAUDE_CONFIG_DIR=/opt/claude-config` (or similar, outside `$HOME`), keep that env var set at runtime, and mount the runtime volume only over `~/.claude` (or wherever user-writable state lands) — physical separation, no reconciliation/merge step needed.
