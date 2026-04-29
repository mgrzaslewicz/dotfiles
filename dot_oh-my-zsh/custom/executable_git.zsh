# git
alias g="git"
alias prpu="git pull --rebase && git push"
alias ggrepall="git branch -a | tr -d \* | sed '/->/d' | xargs git grep"
alias gbackup="git add * && g commit -m 'Manual backup' && git push"
