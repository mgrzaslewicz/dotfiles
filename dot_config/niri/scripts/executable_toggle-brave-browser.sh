#!/usr/bin/env bash
set -euo pipefail

windows_json="$(niri msg -j windows)"

win_id="$(
  jq -r '
    map(select(.app_id == "brave-browser"))
    | first
    | .id // empty
  ' <<< "$windows_json"
)"

if [[ -z "$win_id" ]]; then
  exec brave-browser
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
