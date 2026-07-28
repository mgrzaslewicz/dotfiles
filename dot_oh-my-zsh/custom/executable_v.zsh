# Non recursive current dir list
v() {
  local selected
  if command -v fd >/dev/null 2>&1; then
    selected=$(fd --max-depth 1 --hidden . | fzf)
  else
    # -mindepth 1 eliminates '.'
    selected=$(find . -maxdepth 1 -mindepth 1 | fzf)
  fi

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
  if command -v fd >/dev/null 2>&1; then
    selected=$(fd --max-depth 8 --hidden . | fzf)
  else
    selected=$(find . -maxdepth 8 -mindepth 1 | fzf)
  fi

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
