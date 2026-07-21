#!/bin/bash
set -e

# Gives every host-run Claude Code session a "🖥️  HOST" badge in its status
# line, so it's obvious at a glance which sessions are on the host vs. in the
# claude-toolbox container (which gets its own "🐳 CONTAINER" badge — see
# .containers/claude/setup-and-run-claude.sh).
command -v jq >/dev/null 2>&1 || exit 0

SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

jq --arg cmd "$HOME/.local/bin/claude-statusline.sh '🖥️  HOST'" \
    '.statusLine = {type: "command", command: $cmd}' \
    "$SETTINGS" > "$SETTINGS.tmp"
mv "$SETTINGS.tmp" "$SETTINGS"
