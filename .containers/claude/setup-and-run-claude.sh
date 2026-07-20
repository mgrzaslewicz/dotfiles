set -e

BAKED_CONFIG_DIR="${CLAUDE_CONFIG_DIR_BAKE}"
LIVE_CONFIG_DIR="${HOME}/.claude"
CLAUDE_JSON_DIR="${HOME}/.claude-json-dir"

mkdir -p "${LIVE_CONFIG_DIR}" "${CLAUDE_JSON_DIR}"

# ~/.claude.json lives directly under $HOME, not under ~/.claude, so it needs
# its own volume-backed directory; symlink the expected path into it.
if [ ! -L "${HOME}/.claude.json" ]; then
    rm -f "${HOME}/.claude.json"
    ln -s "${CLAUDE_JSON_DIR}/.claude.json" "${HOME}/.claude.json"
fi

# Plugins always reflect the current image build, regardless of volume staleness
rm -rf "${LIVE_CONFIG_DIR}/plugins"
ln -s "${BAKED_CONFIG_DIR}/plugins" "${LIVE_CONFIG_DIR}/plugins"

# Merge just the plugin-registration keys into the live (volume-backed) settings.json,
# leaving everything else (permissions/theme/hooks) untouched. Use '+' (shallow
# union, right side wins per top-level key) not '*' (deep merge) — '*' would
# leave stale/removed plugin entries behind inside enabledPlugins.
if [ -f "${LIVE_CONFIG_DIR}/settings.json" ]; then
    jq -s '.[0] + {enabledPlugins: .[1].enabledPlugins, extraKnownMarketplaces: .[1].extraKnownMarketplaces}' \
        "${LIVE_CONFIG_DIR}/settings.json" "${BAKED_CONFIG_DIR}/settings.json" \
        > "${LIVE_CONFIG_DIR}/settings.json.tmp"
else
    cp "${BAKED_CONFIG_DIR}/settings.json" "${LIVE_CONFIG_DIR}/settings.json.tmp"
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
