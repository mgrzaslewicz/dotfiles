if command -v lsd >/dev/null 2>&1; then
    alias ls="lsd"
    alias ll="lsd -lah"
    alias llf="lsd -lah | grep $1"
fi
