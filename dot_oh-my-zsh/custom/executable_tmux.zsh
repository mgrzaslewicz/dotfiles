# tmux helpers and optional auto-start
alias tmux-print-screen="tmux capture-pane -pS -1000000"
if [[ -z "$TMUX" ]]; then
  if tmux has-session -t "$USER" 2>/dev/null; then
    tmux new-window -t "$USER" -c "$PWD"
    tmux attach-session -t "$USER"
  else
    tmux new-session -s "$USER" -c "$PWD"
  fi
fi
