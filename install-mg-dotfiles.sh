#!/bin/bash
(cd ~ && \
	git init --quiet && \
	grep -q '\[remote "origin"\]' .git/config  || git remote add origin https://github.com/mgrzaslewicz/dotfiles.git && \
	git fetch origin && \
	git checkout -f master \
	git pull --rebase \
)
(cd ~/.aliases-mg && ./install-zsh-aliases.sh)