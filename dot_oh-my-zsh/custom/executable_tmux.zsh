# tmux helpers and optional auto-start
alias tmux-print-screen="tmux capture-pane -pS -1000000"
if [[ -z "$TMUX" ]]; then
  # Sanitize working directory for tmux session name (replace / with -)
  SESSION_NAME="${PWD//\//-}"
  # Remove leading - if path starts with /
  SESSION_NAME="${SESSION_NAME#-}"
  # Use root as session name if we're at /
  [[ -z "$SESSION_NAME" ]] && SESSION_NAME="root"

  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux new-window -t "$SESSION_NAME" -c "$PWD"
    tmux attach-session -t "$SESSION_NAME"
  else
    tmux new-session -s "$SESSION_NAME" -c "$PWD"
  fi
fi
