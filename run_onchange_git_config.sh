#!/bin/bash
set -e
set -x
# when the list is empty, it will return non-zero code so prevent it
git config --global --unset-all include.path || true
git config --global --add include.path ~/gitalias.txt
git config --global --add include.path ~/my-gitalias.txt
git config --global push.autoSetupRemote true
git config --global core.excludesfile ~/.gitignore_global
git config --global core.commentChar ';'
git config --global pager.branch false
git config --global core.editor nvim
# 3-way conflict resolution in neovim (codediff.nvim, see dot_config/nvim/lua/custom/plugins/git.lua)
git config --global merge.tool codediff
git config --global mergetool.codediff.cmd 'nvim "$MERGED" -c "CodeDiff --exit-on-close merge \"$MERGED\""'

git config --global user.email "mikolaj.grzaslewicz@gmail.com"
git config --global user.name "Mikolaj Grzaslewicz"
