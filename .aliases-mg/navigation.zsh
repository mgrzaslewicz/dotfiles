# navigation
export REPOS=~/repos
export MY_TMP=~/tmp
mkdir -p $REPOS
mkdir -p $MY_TMP
alias repos="cd $REPOS"
alias mytmp="cd $MY_TMP"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ll="lsd -lah"
alias llf="ls -lah | grep $1"
