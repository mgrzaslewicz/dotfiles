#!/bin/bash
ZSH_CUSTOM=~/.oh-my-zsh/custom
for file in ./*.zsh; do
  target="$ZSH_CUSTOM/$(basename "$file")"
  if [ -e "$target" ]; then
    rm "$target"
  fi
  source=$(realpath "$file")
  echo "Creating symlink $source -> $target"
  ln -s "$source" "$target"
done