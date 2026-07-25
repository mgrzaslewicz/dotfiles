#!/usr/bin/env bash
set -euo pipefail

windows_json="$(niri msg -j windows)"

win_id="$(
  jq -r '
    map(select(.app_id == "Logseq"))
    | first
    | .id // empty
  ' <<< "$windows_json"
)"

if [[ -z "$win_id" ]]; then
  notify-send "Logseq" "Starting…" || true
  if command -v logseq >/dev/null 2>&1; then
    exec logseq
  else
    exec flatpak run com.logseq.Logseq
  fi
fi

is_focused="$(
  jq -r --argjson id "$win_id" '
    map(select(.id == $id))
    | first
    | .is_focused // false
  ' <<< "$windows_json"
)"

if [[ "$is_focused" == "true" ]]; then
  niri msg action focus-window-previous
else
  niri msg action focus-window --id "$win_id"
fi
