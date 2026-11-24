#!/bin/bash
set -euo pipefail

# Neither zsh nor bash has a built-in "drop a file in this directory and it
# auto-loads" convention (unlike oh-my-zsh's custom/), so this puts the
# same marker-delimited loader block in both ~/.zshrc and ~/.bashrc, each
# sourcing ~/.shellrc.d/*.sh. One shared directory instead of one per shell:
# the scripts dropped in there are written to run in both zsh and bash.
#
# Touches only the marker block, never the rest of either rc file. A missing
# block is appended; an existing one is rewritten in place, so changes to
# the block itself reach machines that already have an older copy (which is
# also what re-triggers this run_onchange_ script).
MARKER_BEGIN="# >>> chezmoi: shellrc.d loader >>>"
MARKER_END="# <<< chezmoi: shellrc.d loader <<<"

loader_block() {
  local glob="$1"
  echo "$MARKER_BEGIN"
  echo "for _shellrc_d_file in $glob; do"
  echo '  [ -e "$_shellrc_d_file" ] || continue'
  echo '  . "$_shellrc_d_file"'
  echo 'done'
  echo 'unset _shellrc_d_file'
  echo "$MARKER_END"
}

install_loader() {
  local rc_file="$1"
  local glob="$2"
  local block
  block="$(loader_block "$glob")"
  [ -f "$rc_file" ] || touch "$rc_file"
  if grep -qxF "$MARKER_BEGIN" "$rc_file"; then
    local tmp
    tmp="$(mktemp "${rc_file}.XXXXXX")"
    BLOCK="$block" awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
      $0 == begin { print ENVIRON["BLOCK"]; skip = 1; next }
      skip && $0 == end { skip = 0; next }
      !skip { print }
    ' "$rc_file" > "$tmp"
    cat "$tmp" > "$rc_file"
    rm -f "$tmp"
  else
    printf '\n%s\n' "$block" >> "$rc_file"
  fi
}

# zsh's default NOMATCH option errors ("no matches found") on an unmatched
# glob, unlike bash which passes the literal pattern through (caught by the
# `[ -e ]` guard). The (N) glob qualifier is null_glob for this one glob
# only, instead of a `setopt null_glob` that would leak into the whole
# interactive session.
install_loader "$HOME/.zshrc" '"$HOME"/.shellrc.d/*.sh(N)'
install_loader "$HOME/.bashrc" '"$HOME"/.shellrc.d/*.sh'
