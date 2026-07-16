
claude() {
  DOTFILES_DIR="${HOME}/.local/share/chezmoi"
  IMAGE_NAME="claude-toolbox:latest"
  if ! podman image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    podman build \
      -t "$IMAGE_NAME" \
      --build-arg USER_ID="$(id -u)" \
      --build-arg GROUP_ID="$(id -g)" \
      "$DOTFILES_DIR/.containers/claude"
  fi
  mkdir -p "${HOME}/.claude"
  touch "${HOME}/.claude.json"
  podman run \
    -it \
    --rm \
    --userns=keep-id \
    -v "$PWD:/workspace/$(basename "$PWD"):rw" \
    --workdir "/workspace/$(basename "$PWD")" \
    -v "${HOME}/.claude:/home/claude-user/.claude" \
    -v "${HOME}/.claude.json:/home/claude-user/.claude.json" \
    --env TERM="${TERM:-xterm-256color}" \
    claude-toolbox:latest
}

claude-rebuilt () {
  podman image rm claude-toolbox:latest
  claude
}
