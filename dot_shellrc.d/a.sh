# Switch to tmux window with running AI agent
a() {
  # Check if in tmux
  if [[ -z "$TMUX" ]]; then
    echo "Not in a tmux session"
    return 1
  fi

  # Get all panes, check both command name and full process command line for claude
  local panes
  panes=$(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{window_name} [#{pane_current_command}] (#{pane_current_path}) PID:#{pane_pid}' | \
    while IFS= read -r line; do
      # Extract PID from the line
      pid=$(echo "$line" | grep -o 'PID:[0-9]*' | cut -d: -f2)
      # Get full command for this PID (try both Linux and macOS formats)
      cmd=$(ps -p "$pid" -o args= 2>/dev/null || ps -p "$pid" -o command= 2>/dev/null)
      # Check if claude appears in line or in full command
      if echo "$line $cmd" | grep -qi claude; then
        echo "$line"
      fi
    done)

  if [[ -z "$panes" ]]; then
    echo "No agent windows found"
    return 1
  fi

  # Strip PID:... from display, let user select with fzf
  local selected
  selected=$(echo "$panes" | sed 's/ PID:.*//' | fzf)

  if [[ -n "$selected" ]]; then
    # Extract target (session:window.pane is first field)
    local target
    target=$(echo "$selected" | awk '{print $1}')

    # Switch to the selected pane
    tmux switch-client -t "$target"
  fi
}
