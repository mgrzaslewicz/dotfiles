#!/bin/sh
# Remember the window that was active before the current one, across sessions.
# $1 = "session:window_id" that just became active. Called from tmux hooks.
cur=$(tmux show -gqv @cur_win)
[ "$1" = "$cur" ] && exit 0
tmux set -gq @prev_win "$cur"
tmux set -gq @cur_win "$1"
