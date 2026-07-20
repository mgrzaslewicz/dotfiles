set -e

BAKED_CONFIG_DIR="${CLAUDE_CONFIG_DIR_BAKE}"
LIVE_CONFIG_DIR="${HOME}/.claude"
CLAUDE_JSON_DIR="${HOME}/.claude-json-dir"

mkdir -p "${LIVE_CONFIG_DIR}" "${CLAUDE_JSON_DIR}"

# Seed the runtime (volume-backed) mise data dir from the build-time bake, on
# every start. `cp -rn` only fills in what's missing: a fresh volume gets the
# full baked toolchain; an existing volume with project-installed extras
# (e.g. `mise use java@21`) is left untouched; and a rebuilt image's bumped
# node/python/claude version reaches an existing volume too, since mise
# namespaces installs by version (a new version is a new path to copy, never
# an overwrite of one already there).
mkdir -p "${MISE_DATA_DIR}"
cp -rn "${MISE_DATA_DIR_BAKE}/." "${MISE_DATA_DIR}/"
mise reshim

# ~/.claude.json lives directly under $HOME, not under ~/.claude, so it needs
# its own volume-backed directory; symlink the expected path into it.
if [ ! -L "${HOME}/.claude.json" ]; then
    rm -f "${HOME}/.claude.json"
    ln -s "${CLAUDE_JSON_DIR}/.claude.json" "${HOME}/.claude.json"
fi

# Marketplace/plugin-cache registration is handled by Claude Code itself via
# CLAUDE_CODE_PLUGIN_SEED_DIR (set in the Dockerfile) — no script needed here.
#
# enabledPlugins isn't covered by the seed dir, so add any baked-in plugin
# that's missing from the live settings.json. '+' on enabledPlugins is a
# per-key union where the live side wins on conflicts, so a plugin the user
# has since disabled/reconfigured stays untouched — this only fills gaps.
if [ -f "${LIVE_CONFIG_DIR}/settings.json" ]; then
    jq -s '.[0] + {enabledPlugins: ((.[1].enabledPlugins // {}) + (.[0].enabledPlugins // {}))}' \
        "${LIVE_CONFIG_DIR}/settings.json" "${BAKED_CONFIG_DIR}/settings.json" \
        > "${LIVE_CONFIG_DIR}/settings.json.tmp"
else
    jq '{enabledPlugins: (.enabledPlugins // {})}' "${BAKED_CONFIG_DIR}/settings.json" \
        > "${LIVE_CONFIG_DIR}/settings.json.tmp"
fi
mv "${LIVE_CONFIG_DIR}/settings.json.tmp" "${LIVE_CONFIG_DIR}/settings.json"

# rtk's hook lands in the volume-backed settings.json and survives restarts;
# skip the subprocess once it's already there instead of relying on rtk's own no-op check.
if ! jq -e '(.hooks.PreToolUse // []) | any(.hooks[]?.command == "rtk hook claude")' \
    "${LIVE_CONFIG_DIR}/settings.json" >/dev/null 2>&1; then
    yes n | rtk init -g --auto-patch
fi

# codegraph install --location local writes .mcp.json into the mounted project
# directory (persists on the host), so skip it once that registration exists.
if ! jq -e '.mcpServers.codegraph' "${PWD}/.mcp.json" >/dev/null 2>&1; then
    codegraph install --yes --target claude --location local
fi

# .codegraph/ also persists on the host per project; sync it incrementally
# instead of paying for a fresh init every start once it already exists.
if [ -d "${PWD}/.codegraph" ]; then
    codegraph sync
else
    codegraph init
fi

claude
