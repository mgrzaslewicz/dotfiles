# tmux helpers and optional auto-start
alias tmux-print-screen="tmux capture-pane -pS -1000000"
if [[ -z "$TMUX" ]]; then
  SESSION_NAME="${PWD}"
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux new-window -t "$SESSION_NAME" -c "$PWD"
    tmux attach-session -t "$SESSION_NAME"
  else
    tmux new-session -s "$SESSION_NAME" -c "$PWD"
  fi
fi
