yaz() {
    local cwd_file code
    cwd_file=$(mktemp)
    if yazi --cwd-file "$cwd_file" "$@"; then
	cwd=$(cat "$cwd_file")
        rm -f "$cwd_file"
        cd $cwd
    else
        code=$?
        rm -f "$cmd_file"
        return "$code"
    fi
}
