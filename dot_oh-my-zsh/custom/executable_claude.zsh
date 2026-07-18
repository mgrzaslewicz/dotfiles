
claude-toolbox() {
  DOTFILES_DIR="${HOME}/.local/share/chezmoi"
  IMAGE_NAME="claude-toolbox:latest"
  CONTAINER_NAME="claude-toolbox"
  if ! podman image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    podman build \
      -t "$IMAGE_NAME" \
      --build-arg USER_ID="$(id -u)" \
      --build-arg GROUP_ID="$(id -g)" \
      "$DOTFILES_DIR/.containers/claude"
  fi
  mkdir -p "${HOME}/.claude"
  touch "${HOME}/.claude.json"

  if podman container exists "$CONTAINER_NAME"; then
    if [ "$(podman inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" = "true" ]; then
      podman exec -it "$CONTAINER_NAME" claude
    else
      podman start -ai "$CONTAINER_NAME"
    fi
  else
    podman run \
      -it \
      --name "$CONTAINER_NAME" \
      --userns=keep-id \
      -v "$PWD:/workspace/$(basename "$PWD"):rw" \
      -v "${HOME}/.claude:/home/claude-user/.claude:rw" \
      -v "${HOME}/.claude.json:/home/claude-user/.claude.json:rw" \
      --workdir "/workspace/$(basename "$PWD")" \
      --env TERM="${TERM:-xterm-256color}" \
      claude-toolbox:latest
  fi
}

claude-toolbox-new () {
  podman rm -f claude-toolbox
  podman image rm claude-toolbox:latest
  claude-toolbox
}
