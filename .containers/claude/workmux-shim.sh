#!/bin/sh
# Stand-in for `workmux` inside the container, called by the workmux-status
# plugin's hooks (`workmux register-agent`, `workmux set-window-status ...`).
# The real workmux talks to the host tmux server, which this container
# deliberately can't reach (a tmux socket is a full host shell). Instead,
# each call is spooled as a file into a dir the host-side ~/.local/bin/claude
# wrapper mounts and relays to the real workmux, which validates the event
# before acting on it. No relay dir (not launched from a tmux pane, or no
# workmux on the host) means a silent no-op, so hooks never fail.
spool="${WORKMUX_RELAY_DIR:-}"
[ -n "$spool" ] && [ -d "$spool" ] || exit 0

# Hook JSON on stdin carries session_id/prompt, which workmux uses for
# session binding and prompt capture; forward it alongside the args.
payload=""
if [ ! -t 0 ]; then
    payload="$(base64 -w0)"
fi

# Write-then-rename so the host relay never reads a half-written event;
# nanosecond names keep events in order.
name="$(date +%s%N)-$$"
printf '%s\n%s\n' "$*" "$payload" > "$spool/.$name.tmp"
mv "$spool/.$name.tmp" "$spool/$name.evt"
