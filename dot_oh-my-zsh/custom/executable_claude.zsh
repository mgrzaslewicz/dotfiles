
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
  if [[ -f "${HOME}/.claude.json" && ! -L "${HOME}/.claude.json" ]]; then
    mv "${HOME}/.claude.json" "${HOME}/.claude/.claude.json"
    ln -s ".claude/.claude.json" "${HOME}/.claude.json"
  fi
  podman run \
    -it \
    --rm \
    --userns=keep-id \
    -v "$PWD:/workspace/$(basename "$PWD"):rw" \
    --workdir "/workspace/$(basename "$PWD")" \
    -v "${HOME}/.claude:/home/claude-user/.claude" \
    --env HOME=/home/claude-user/.claude \
    --env TERM="${TERM:-xterm-256color}" \
    claude-toolbox:latest
}

claude-rebuilt () {
  podman image rm claude-toolbox:latest
  claude
}
