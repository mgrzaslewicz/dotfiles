#!/usr/bin/env bash

# 1. Get list of windows from Niri in JSON format
# 2. Parse with JQ to format as: "ID | App Name: Window Title"
# 3. Feed into Fuzzel (dmenu mode)
# 4. Extract the ID from the selection
# 5. Tell Niri to focus that ID

SELECTION=$(niri msg --json windows | jq -r '
  .[]
  | select(.is_focused == false)
  | ((.id | tostring) | (3 - length) as $l | (if $l > 0 then "   "[0:$l] + . else . end)) as $id
  | "\($id) | \(.app_id // "unknown"): \(.title)\u0000icon\u001f\(.app_id // "window-manager")"
' | fuzzel --width 50 --dmenu --prompt="Switch To > ")

# If nothing selected, exit
if [ -z "$SELECTION" ]; then
    exit 0
fi

# Extract the ID (the first field)
WINDOW_ID=$(echo "$SELECTION" | awk '{print $1}')

# Focus the window
niri msg action focus-window --id "$WINDOW_ID"
