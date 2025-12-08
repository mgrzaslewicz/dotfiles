# tmux helpers and optional auto-start
alias tmux-print-screen="tmux capture-pane -pS -1000000"
if [[ -z "$TMUX" ]]; then
  tmux attach-session -t "$USER" || tmux new-session -s "$USER"
fi
