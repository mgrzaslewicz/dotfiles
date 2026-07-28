# boost file search
alias greperrors="grep -i 'fatal\|error\|exception\|timeout\|waiting\|fail\|unable\|lock\|block'"
alias grepanywhere="grep -nr . -e $1"

if command -v rg >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
  # fuzzy-filter ripgrep hits, preview in context, open at the matched line
  rgf() {
    local preview_cmd='cat {1}'
    command -v bat >/dev/null 2>&1 && preview_cmd='bat --style=numbers --color=always --highlight-line {2} {1}'

    local picked file line
    picked=$(rg --line-number --no-heading . |
      fzf --delimiter : --preview "$preview_cmd" --preview-window '+{2}-/2')

    [[ -z "$picked" ]] && return
    file=$(cut -d: -f1 <<<"$picked")
    line=$(cut -d: -f2 <<<"$picked")
    vi "$file" "+$line"
  }
fi
