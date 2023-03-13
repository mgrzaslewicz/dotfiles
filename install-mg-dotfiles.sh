#!/bin/bash
set -e
set -x

REPO=https://github.com/mgrzaslewicz/dotfiles.git
cd ~
git init --quiet
if ! grep -q '\[remote "origin"\]' .git/config; then
  git remote add origin $REPO
fi
git config --unset core.bare
git fetch origin
git checkout master
git pull --rebase

(cd ~/.aliases-mg && ./install-zsh-aliases.sh)
