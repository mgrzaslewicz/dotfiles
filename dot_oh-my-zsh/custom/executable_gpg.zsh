if command -v gpgconf >/dev/null 2>&1; then
    export GPG_TTY=$(tty)
    gpgconf --launch gpg-agent
fi
