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

# when the list is empty, it will return non-zero code so prevent it
git config --global --unset-all include.path || true
git config --global --add include.path ~/gitalias.txt
git config --global --add include.path ~/my-gitalias.txt

git config --global user.email "mikolaj.grzaslewicz@gmail.com"
git config --global user.name "Mikolaj Grzaslewicz"

(cd ~/.aliases-mg && ./install-zsh-aliases.sh)
