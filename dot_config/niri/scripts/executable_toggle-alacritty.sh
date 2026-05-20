#!/usr/bin/env bash
set -euo pipefail

TITLE="startup-alacritty"

windows_json="$(niri msg -j windows)"

win_id="$(
  jq -r --arg title "$TITLE" '
    map(select(.app_id == "Alacritty" or .app_id == "alacritty"))
    | map(select(.title == $title))
    | first
    | .id // empty
  ' <<< "$windows_json"
)"

if [[ -z "$win_id" ]]; then
  exec alacritty --title "$TITLE"
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
