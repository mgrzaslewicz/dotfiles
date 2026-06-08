# Non recursive current dir list
v() {
  local selected
  # -mindepth 1 eliminates '.'
  selected=$(find . -maxdepth 1 -mindepth 1 | fzf)

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

# Recursive current dir list
vv() {
  local selected
  selected=$(find . -maxdepth 8 -mindepth 1 | fzf)

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
