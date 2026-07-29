# boost file search
alias greperrors="grep -i 'fatal\|error\|exception\|timeout\|waiting\|fail\|unable\|lock\|block'"
alias grepanywhere="grep -nr . -e $1"

if command -v rg >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
  # fuzzy-filter ripgrep hits, preview in context, open at the matched line
  rgf() {
    local bat_bin=""
    command -v bat >/dev/null 2>&1 && bat_bin="bat"
    command -v batcat >/dev/null 2>&1 && bat_bin="batcat"

    local preview_cmd='cat {1}'
    [[ -n "$bat_bin" ]] && preview_cmd="$bat_bin --style=numbers --color=always --highlight-line {2} {1}"

    local picked file line
    picked=$(rg --line-number --no-heading . |
      fzf --delimiter : --preview "$preview_cmd" --preview-window '+{2}-/2')

    [[ -z "$picked" ]] && return
    file=$(cut -d: -f1 <<<"$picked")
    line=$(cut -d: -f2 <<<"$picked")
    "${EDITOR:-vi}" "$file" "+$line"
  }
fi

if command -v fzf >/dev/null 2>&1; then
  # fuzzy-pick a logseq_search.py tag match, preview in context, open at the matched line
  lgf() {
    if [[ -z "$1" ]]; then
      echo "usage: lgf <tag> [logseq_search.py args...]" >&2
      return 1
    fi
    local tag="$1"
    shift

    local graph_dir="${LOGSEQ_GRAPH_DIR:-$HOME/Logseq}"
    local bat_bin=""
    command -v bat >/dev/null 2>&1 && bat_bin="bat"
    command -v batcat >/dev/null 2>&1 && bat_bin="batcat"

    local preview_cmd='cat {1}'
    [[ -n "$bat_bin" ]] && preview_cmd="$bat_bin --style=numbers --color=always --highlight-line {2} {1}"

    local picked rel_path line
    picked=$(cd "$graph_dir" && logseq_search.py "$tag" "$@" |
      fzf --delimiter : --preview "$preview_cmd" --preview-window '+{2}-/2')

    [[ -z "$picked" ]] && return
    rel_path=$(cut -d: -f1 <<<"$picked")
    line=$(cut -d: -f2 <<<"$picked")
    "${EDITOR:-vi}" "$graph_dir/$rel_path" "+$line"
  }
fi
