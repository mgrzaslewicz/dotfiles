#!/bin/sh
# Claude Code statusLine command. First arg is a badge string identifying
# which environment this session is running in (host vs. container) — see
# run_onchange_claude_statusline.sh and .containers/claude/setup-and-run-claude.sh
# for where each environment wires in its own badge.
badge="$1"
input="$(cat)"
model="$(printf '%s' "$input" | jq -r '(.model.display_name // "?")')"
dir="$(printf '%s' "$input" | jq -r '((.workspace.current_dir // "?") | split("/") | last)')"
# context_window.used_percentage is null before the first API call and right
# after /compact; total_input_tokens already sums input+cache tokens per the
# Claude Code statusline docs, so no cumulative usage needs to be tracked here.
ctx="$(printf '%s' "$input" | jq -r '
  if .context_window.used_percentage == null then "-"
  else
    (((.context_window.total_input_tokens // 0) / 1000) | floor) as $used |
    (((.context_window.context_window_size // 200000) / 1000) | floor) as $total |
    "\(.context_window.used_percentage | floor)% (\($used)k/\($total)k)"
  end
')"
printf '%s  %s · %s · ctx %s\n' "$badge" "$model" "$dir" "$ctx"
