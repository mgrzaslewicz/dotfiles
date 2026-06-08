v() {
  local selected
  selected=$(find * . -maxdepth 8 | fzf)

  if [[ -n "$selected" ]]; then
    if [[ -d "$selected" ]]; then
      cd "$selected" || exit
    elif [[ $(file --mime-type -b "$selected") == text/* ]]; then
      vi "$selected"
    else
      ls -l "$selected"
    fi
  fi
}
