# Reconciliation strategy for build-time bake vs runtime volume

Type: grilling
Status: resolved
Blocked by: 01

## Question

A named volume persists across container runs *and* across image rebuilds. If you rebuild the image with a new/updated plugin baked in, but an existing volume already holds an older `~/.claude`, how does the new bake actually reach the running container? Candidate strategies: physical separation (plugins live outside the volume's mount path, per ticket 01's findings), a merge-on-start step in `setup-and-run-claude.sh` (e.g. copy-if-missing from the baked defaults into the volume), or requiring an explicit reset (see ticket 05) whenever the image changes. Pick the strategy, informed by ticket 01's answer.

## Answer

Runtime persistence is wanted (session history, project memory, MCP trust state) — so a volume over `~/.claude` (+ `~/.claude.json`) stays in the design. Reconciliation strategy, confirmed with the user:

1. **Build time**: run the marketplace-add/plugin-install steps in the Dockerfile with `CLAUDE_CONFIG_DIR` pointed at a build-only path *outside* `$HOME`, e.g. `/opt/claude-config-baked` (per ticket 01). This produces `/opt/claude-config-baked/plugins/{cache,marketplaces,known_marketplaces.json}` and a `settings.json` carrying `enabledPlugins`/`extraKnownMarketplaces`, all inside the image layer, never touched by any volume.
2. **Run time**: the live config uses the default `~/.claude` / `~/.claude.json` paths, which the runtime volume covers. Before invoking `claude`, the entrypoint (`setup-and-run-claude.sh`):
   - (Re-)links `~/.claude/plugins` to `/opt/claude-config-baked/plugins` (removing whatever the volume currently has there first), so plugin code always reflects the *current* image build, regardless of volume staleness.
   - Runs a small `jq` step that injects/overwrites just the `enabledPlugins` and `extraKnownMarketplaces` keys in the live (volume-backed) `~/.claude/settings.json` from the baked copy at `/opt/claude-config-baked/settings.json`, leaving every other key (permissions, theme, hooks — anything the user edited live, e.g. via `/permissions`) untouched.
3. This runs on **every** container start, so a rebuilt image's new plugin version reaches a pre-existing volume automatically — no explicit reset needed for plugin updates specifically (see ticket 05 for whether a reset is still needed for other reasons, e.g. corrupted session state).

This keeps `settings.json` itself fully live/volume-backed (per the user's choice) rather than baked wholesale, at the cost of the small `jq` merge step running on every start.
