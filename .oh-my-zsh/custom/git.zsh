# git
alias g="git"
alias prpu="git pull --rebase && git push"
alias ggrepall="git branch -a | tr -d \* | sed '/->/d' | xargs git grep"