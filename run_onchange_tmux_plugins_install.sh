#!/bin/bash
set -e
set -x

TMUX_PLUGINS_DIR="$HOME/.tmux/plugins/tpm"

if [ -d "$TMUX_PLUGINS_DIR" ]; then
  "$TMUX_PLUGINS_DIR/bin/install_plugins"
fi
