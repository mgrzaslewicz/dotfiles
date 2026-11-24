yaz() {
    local cwd_file cwd code
    cwd_file=$(mktemp)
    if yazi --cwd-file "$cwd_file" "$@"; then
        cwd=$(cat "$cwd_file")
        rm -f "$cwd_file"
        cd "$cwd" || return
    else
        code=$?
        rm -f "$cwd_file"
        return "$code"
    fi
}
