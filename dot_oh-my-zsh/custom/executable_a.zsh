# Switch to tmux window with running AI agent
a() {
  # Check if in tmux
  if [[ -z "$TMUX" ]]; then
    echo "Not in a tmux session"
    return 1
  fi

  # Get all panes with claude in command, format for fzf
  local panes
  panes=$(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{window_name} [#{pane_current_command}] (#{pane_current_path})' | \
    grep -i claude)

  if [[ -z "$panes" ]]; then
    echo "No agent windows found"
    return 1
  fi

  # Let user select with fzf
  local selected
  selected=$(echo "$panes" | fzf)

  if [[ -n "$selected" ]]; then
    # Extract target (session:window.pane is first field)
    local target
    target=$(echo "$selected" | awk '{print $1}')

    # Switch to the selected pane
    tmux switch-client -t "$target"
  fi
}
