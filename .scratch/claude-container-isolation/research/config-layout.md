# Claude Code config layout & plugin shadowing

Research for redesigning `.containers/claude/` (podman) to use a container-only
named volume instead of a host bind-mount over `~/.claude`, without losing the
plugins/marketplaces baked in at `Dockerfile` build time.

Environment used for primary-source checks: this machine, Claude Code
`2.1.205` (Homebrew cask, `darwin-arm64`), installed at
`/opt/homebrew/Caskroom/claude-code/2.1.205/claude`, `HOME=/Users/mikolaj.grzaslewicz@olx.pl`.

---

## 1. What lives under `~/.claude` (and other config locations)

Enumerated from `ls -la ~/.claude`, `cat ~/.claude/settings.json`,
`cat ~/.claude/plugins/*.json`, and `python3 -c "json.load(open('~/.claude.json'))"`
on this host, cross-checked against
[Settings](https://code.claude.com/docs/en/settings) and
[Plugins reference](https://code.claude.com/docs/en/plugins-reference).

| Data | Location | Notes / source |
|---|---|---|
| User settings (permissions, hooks, theme, `enabledPlugins`, `extraKnownMarketplaces`) | `~/.claude/settings.json` | File inspected directly; matches the "User Scope" row in the settings doc |
| Plugin marketplaces (registry + clone locations) | `~/.claude/plugins/known_marketplaces.json`, actual git clones in `~/.claude/plugins/marketplaces/<name>/` | Inspected directly (`mattpocock`, `claude-plugins-official` both present with `installLocation` pointing under `~/.claude/plugins/marketplaces/`) |
| Installed plugin file copies (the actual plugin code, not just the "installed" flag) | `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` | Confirmed by inspection and by [Plugins reference § Plugin caching and file resolution](https://code.claude.com/docs/en/plugins-reference#plugin-caching-and-file-resolution): *"Claude Code copies marketplace plugins to the user's local plugin cache (`~/.claude/plugins/cache`) rather than using them in-place."* |
| Plugin persistent data dirs (e.g. installed `node_modules` for a plugin) | `~/.claude/plugins/data/{id}/` | [Plugins reference § Persistent data directory](https://code.claude.com/docs/en/plugins-reference#persistent-data-directory) — resolves `${CLAUDE_PLUGIN_DATA}` |
| Personal skills-directory plugins (`claude plugin init`) | `~/.claude/skills/<name>/` | [Plugins reference § plugin init](https://code.claude.com/docs/en/plugins-reference#plugin-init) and § Skills-directory plugins |
| Project-scope plugins/settings (checked into the repo, shared with the team) | `<project>/.claude/settings.json`, `<project>/.claude/skills/`, `<project>/.mcp.json` | Doc table in [Settings](https://code.claude.com/docs/en/settings) — lives in the project tree, **not** under `~/.claude` |
| Local-scope (personal, gitignored) project overrides | `<project>/.claude/settings.local.json` | Same doc |
| Managed/enterprise settings (IT-deployed, read-only) | macOS `/Library/Application Support/ClaudeCode/managed-settings.json` (+ MDM plist `com.anthropic.claudecode`); Linux `/etc/claude-code/managed-settings.json`; Windows registry/`Program Files` | Same doc |
| MCP server config (user scope) | `~/.claude.json` → top-level `mcpServers` key | Inspected directly: contains `atlassian-mcp-server`, `codegraph`, `new-relic-mcp-server`, `tolaria` entries with `command`/`url`/`headers` |
| MCP server config (per-project overrides, trust state) | `~/.claude.json` → `projects.<abs-path>.{mcpServers,enabledMcpjsonServers,disabledMcpjsonServers,hasTrustDialogAccepted,...}` | Inspected directly — 17 project entries on this host, each carrying its own trust-dialog flag and last-session metrics |
| Session/conversation transcripts | `~/.claude/projects/<sanitized-cwd>/<session-id>.jsonl` | Directory listing shows one folder per project path (e.g. `-Users-mikolaj-grzaslewicz-olx-pl-repos-mg-dotfiles`) |
| Cross-session prompt history (up-arrow recall) | `~/.claude/history.jsonl` | Inspected directly |
| Project memory (instructions) | `~/.claude/CLAUDE.md` (user-level, global) vs. `<project>/CLAUDE.md` / `<project>/.claude/CLAUDE.md` (project-level, walked up from cwd) | User CLAUDE.md inspected directly; project-level behavior per [Plugins guide](https://code.claude.com/docs/en/plugins) note that plugin `CLAUDE.md` is *not* auto-loaded the same way |
| Credentials (OAuth / API keys) | macOS Keychain when available, else `~/.claude/.credentials.json` (mode 600) | File present with 600 perms; behavior documented in [Plugins reference § User configuration](https://code.claude.com/docs/en/plugins-reference#user-configuration): *"Sensitive values go to the macOS Keychain, or to `~/.claude/.credentials.json` on platforms where no supported keychain is available."* |
| Misc daemon/cache/telemetry state | `~/.claude/{daemon,daemon.log,cache,telemetry,tasks,jobs,sessions,session-env,shell-snapshots,file-history,backups}` | Inspected via directory listing; not documented in detail, operational/internal state |
| Policy/remote caches | `~/.claude/{policy-limits.json,remote-settings.json,mcp-needs-auth-cache.json}` | Inspected directly |

Key structural point for the container redesign: **the plugin/marketplace/skills
data that the Dockerfile's `claude plugin marketplace add` + `claude plugin
install` produce is written almost entirely under `~/.claude/plugins/`**
(cache, marketplaces, known_marketplaces.json) plus one `enabledPlugins` entry
in `~/.claude/settings.json`. All of that sits inside the exact subtree a
host-bind-mount (or a naive named-volume mount) over `~/.claude` would replace.

---

## 2. Can plugins/skills be installed somewhere other than the user's home config dir?

**Two independent mechanisms exist. One (`CLAUDE_CONFIG_DIR`) is exactly what's needed and was empirically verified on this host; the other (project scope) is a weaker, partial option.**

### a) `CLAUDE_CONFIG_DIR` — moves the *entire* config root, verified empirically

`claude --help`, `claude plugin --help`, and the official docs
([env-vars](https://code.claude.com/docs/en/env-vars)) do **not** mention
`CLAUDE_CONFIG_DIR` at all — it is undocumented. Its existence is corroborated
by two open GitHub issues on `anthropics/claude-code`:
[#25762](https://github.com/anthropics/claude-code/issues/25762) ("Add
environment variable to configure .claude config directory location") and
[#33430](https://github.com/anthropics/claude-code/issues/33430) ("[DOCS]
Document CLAUDE_CONFIG_DIR environment variable for multi-account setups"),
both describing it as a real, working, but undocumented feature.

I verified it directly on this machine (v2.1.205):

```
export CLAUDE_CONFIG_DIR=/private/tmp/claude-cfg-test
claude doctor                                    # → creates .claude.json + backups/ there
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install code-review@claude-plugins-official
```

Result: the **entire** config tree was created under
`/private/tmp/claude-cfg-test/` instead of `~/.claude` / `~/.claude.json` —
`settings.json` (with `extraKnownMarketplaces` and `enabledPlugins`),
`.claude.json`, `backups/`, and critically `plugins/{cache,marketplaces,
known_marketplaces.json,installed_plugins.json}` including the actual cloned
marketplace repo and the installed plugin's cached files. The real
`~/.claude/plugins/known_marketplaces.json` on the host was confirmed
unchanged after the test (still only listing `claude-plugins-official` from a
prior session and `mattpocock`, with no trace of the test run).

**Implication for the container redesign:** set `CLAUDE_CONFIG_DIR` to a path
*outside* `$HOME`/`~/.claude` at build time in the Dockerfile (e.g.
`/opt/claude-config`), run the marketplace-add/install steps there, bake that
env var into the image (`ENV CLAUDE_CONFIG_DIR=/opt/claude-config`), and at
runtime only mount the named volume over that same fixed path (or over some
other path that is never `/opt/claude-config`). A volume mounted over
`~/.claude` would then no longer intersect the baked plugin data at all, so
nothing is shadowed. This is a full, clean answer to "install to a location
other than the user's home config dir."

Caveat: because this is undocumented, Anthropic could change or remove it
without notice in a future release — worth a version pin / smoke test in CI
if adopted long-term.

### b) Plugin/marketplace install `--scope project` — partial, and doesn't solve the cache problem alone

`claude plugin install --help` and `claude plugin marketplace add --help`
(local `--help` output) both expose `-s, --scope <scope>` /
`--scope <scope>` = `user` (default) | `project` | `local` (and `managed` for
`plugin update`/enable/disable). Per
[Plugins reference § Plugin installation scopes](https://code.claude.com/docs/en/plugins-reference#plugin-installation-scopes):

| Scope | Settings file | 
|---|---|
| `user` | `~/.claude/settings.json` |
| `project` | `<project>/.claude/settings.json` |
| `local` | `<project>/.claude/settings.local.json` |
| `managed` | OS/enterprise managed settings |

This only redirects **where the `enabledPlugins` reference and marketplace
declaration are written** — it does *not* redirect the plugin cache. Per the
same doc: *"Claude Code copies marketplace plugins to the user's local plugin
cache (`~/.claude/plugins/cache`) rather than using them in-place"* — this
happens regardless of install scope. So `--scope project` alone still leaves
the actual plugin bytes under `~/.claude/plugins/cache`, which a home-directory
volume swap would still wipe; it would only solve the problem if combined with
`CLAUDE_CONFIG_DIR` (redundant) or if the project directory itself is what's
being repopulated at every container start (not the scenario here).

The one option that entirely avoids `~/.claude` is a **project-scope
skills-directory plugin**: any folder under `<project-root>/.claude/skills/`
containing a `.claude-plugin/plugin.json` loads in place, with "no marketplace
and no install step" and is *never* copied to `~/.claude/plugins/cache`
(Plugins reference § Skills-directory plugins). But this requires accepting
the workspace trust dialog per project on every session (trust-dialog
acceptance state itself lives in `~/.claude.json`, so it would also reset on
every home-volume swap), and only supports the single "load from project
skills dir" plugin type — not marketplace-installed plugins the Dockerfile
currently uses (`mattpocock-skills@mattpocock`). Not a full substitute for
`CLAUDE_CONFIG_DIR`.

---

## 3. Merge vs. wholesale override behavior

Per [Settings](https://code.claude.com/docs/en/settings), Claude Code *does*
have a documented scope-precedence system for settings that exist as
**separate files at separate paths** (managed > CLI args >
`.claude/settings.local.json` > `.claude/settings.json` > `~/.claude/settings.json`).
Within that system, override is **whole-key, not deep-merge**: *"When the same
setting appears in multiple scopes, the highest-precedence scope wins
completely. Lower scopes do not merge in; they are ignored entirely,"* with
one documented exception — `permissions` `allow`/`ask`/`deny` rules merge
(union) across scopes rather than override.

**However, this scope-precedence system is irrelevant to the container's
shadowing problem, and that's the key finding for the redesign.** The
Dockerfile-vs-bind-mount conflict is not two Claude Code *scopes* competing
(that mechanism only arbitrates between genuinely different paths, e.g. a
project's `.claude/settings.json` vs. the user's `~/.claude/settings.json`).
It's the **same path** (`~/.claude`) having its filesystem contents replaced
wholesale by a mount, which happens beneath Claude Code entirely — the OS
mounts a different directory tree over the identical path, so there is nothing
left for Claude Code's own merge logic to arbitrate between. The build-time
content isn't "outranked," it's gone from that path. So: **no in-app merge
exists (or could exist) for this scenario; it is unconditional, wholesale
directory shadowing at the mount layer.**

The only way to avoid it is what §2 concludes: put the build-time-baked
plugin data at a path the runtime volume never covers — `CLAUDE_CONFIG_DIR`
pointed outside `~/.claude`/`$HOME` being the clean, verified way to do that.

---

## Sources consulted

- `claude --help`, `claude plugin --help`, `claude plugin marketplace --help`,
  `claude plugin marketplace add --help`, `claude plugin install --help` — this
  host, Claude Code 2.1.205.
- `claude doctor`, and an empirical `CLAUDE_CONFIG_DIR=/private/tmp/claude-cfg-test`
  test run (`claude doctor`, `claude plugin marketplace add
  anthropics/claude-plugins-official`, `claude plugin install
  code-review@claude-plugins-official`) — this host.
- Direct filesystem inspection of `~/.claude/**`, `~/.claude.json`,
  `~/.claude/settings.json`, `~/.claude/plugins/*.json`, `~/.claude/mcp.json` —
  this host.
- https://code.claude.com/docs/en/plugins (redirect target of
  `docs.claude.com/en/docs/claude-code/plugins`)
- https://code.claude.com/docs/en/plugins-reference
- https://code.claude.com/docs/en/settings
- https://code.claude.com/docs/en/env-vars
- https://github.com/anthropics/claude-code/issues/25762
- https://github.com/anthropics/claude-code/issues/33430
