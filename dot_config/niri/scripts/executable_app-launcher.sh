#!/usr/bin/env bash

# Mod+D launcher: normal fuzzel app launcher, plus one entry per already-open
# window (suffixed with the window's title) so you can jump straight to it.
#
# Implemented by generating a throwaway .desktop file per open window and
# pointing fuzzel at it via XDG_DATA_DIRS, so fuzzel's own fuzzy search/icon
# handling is reused instead of reimplementing a second menu.

WINDOWS_DATA_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fuzzel-windows"
APPS_DIR="$WINDOWS_DATA_DIR/applications"

rm -rf "$WINDOWS_DATA_DIR"
mkdir -p "$APPS_DIR"

niri msg --json windows | jq -r '
  .[]
  | select(.is_focused == false)
  | [(.id | tostring), (.app_id // "window-manager"), .title] | @tsv
' | while IFS=$'\t' read -r id app_id title; do
    cat > "$APPS_DIR/niri-window-$id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$app_id — $title
Icon=$app_id
Exec=niri msg action focus-window --id $id
Terminal=false
NoDisplay=false
EOF
done

XDG_DATA_DIRS="$WINDOWS_DATA_DIR:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" exec fuzzel --width 50
