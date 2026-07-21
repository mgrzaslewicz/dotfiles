#!/bin/sh
# Claude Code statusLine command. First arg is a badge string identifying
# which environment this session is running in (host vs. container) — see
# run_onchange_claude_statusline.sh and .containers/claude/setup-and-run-claude.sh
# for where each environment wires in its own badge.
badge="$1"
input="$(cat)"
model="$(printf '%s' "$input" | jq -r '.model.display_name // "?"')"
dir="$(printf '%s' "$input" | jq -r '.workspace.current_dir // "?" | split("/") | last')"
printf '%s  %s · %s\n' "$badge" "$model" "$dir"
