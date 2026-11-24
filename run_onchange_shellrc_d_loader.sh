#!/bin/bash
set -euo pipefail

# Neither zsh nor bash has a built-in "drop a file in this directory and it
# auto-loads" convention (unlike oh-my-zsh's custom/), so this appends the
# same marker-delimited loader block to both ~/.zshrc and ~/.bashrc, each
# sourcing ~/.shellrc.d/*.sh. One shared directory instead of one per shell:
# the function bodies dropped in there are plain portable shell with no
# zsh- or bash-only syntax, so there's nothing to fork.
#
# Idempotent and append-only by design: it never touches the rest of either
# rc file, and re-running (e.g. after this script's own content changes,
# which is what re-triggers a run_onchange_ script) is a no-op once a
# marker block is present -- so a user who deletes one by hand won't have
# it silently restored on the next unrelated apply.
MARKER_BEGIN="# >>> chezmoi: shellrc.d loader >>>"
MARKER_END="# <<< chezmoi: shellrc.d loader <<<"

append_loader() {
  local rc_file="$1"
  local zsh_setup="$2"
  [ -f "$rc_file" ] || touch "$rc_file"
  if ! grep -qF "$MARKER_BEGIN" "$rc_file"; then
    {
      echo ""
      echo "$MARKER_BEGIN"
      if [ -n "$zsh_setup" ]; then
        echo "$zsh_setup"
      fi
      echo 'for _shellrc_d_file in "$HOME"/.shellrc.d/*.sh; do'
      echo '  [ -e "$_shellrc_d_file" ] || continue'
      echo '  . "$_shellrc_d_file"'
      echo 'done'
      echo 'unset _shellrc_d_file'
      echo "$MARKER_END"
    } >> "$rc_file"
  fi
}

# zsh's default NOMATCH option errors ("no matches found") on an unmatched
# glob, unlike bash which just passes the literal pattern through (caught by
# the `[ -e ]` guard above) -- null_glob makes zsh behave the same way.
append_loader "$HOME/.zshrc" 'setopt null_glob'
append_loader "$HOME/.bashrc" ''
