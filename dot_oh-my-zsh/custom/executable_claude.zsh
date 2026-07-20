
CLAUDE_TOOLBOX_VOLUME="claude-toolbox-config"
CLAUDE_TOOLBOX_VOLUME_JSON="claude-toolbox-config-json"

claude-toolbox() {
  DOTFILES_DIR="${HOME}/.local/share/chezmoi"
  IMAGE_NAME="claude-toolbox:latest"
  if ! podman image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    podman build \
      -t "$IMAGE_NAME" \
      --build-arg USER_ID="$(id -u)" \
      --build-arg GROUP_ID="$(id -g)" \
      "$DOTFILES_DIR/.containers/claude"
  fi
  podman volume create "$CLAUDE_TOOLBOX_VOLUME" >/dev/null 2>&1 || true
  podman volume create "$CLAUDE_TOOLBOX_VOLUME_JSON" >/dev/null 2>&1 || true
  podman run \
    -it \
    --rm \
    --userns=keep-id \
    -v "$PWD:/workspace/$(basename "$PWD"):rw" \
    -v "${CLAUDE_TOOLBOX_VOLUME}:/home/claude-user/.claude:rw" \
    -v "${CLAUDE_TOOLBOX_VOLUME_JSON}:/home/claude-user/.claude-json-dir:rw" \
    --workdir "/workspace/$(basename "$PWD")" \
    --env TERM="${TERM:-xterm-256color}" \
    claude-toolbox:latest
}

claude-toolbox-new () {
  podman image rm claude-toolbox:latest
  claude-toolbox
}

claude-toolbox-reset () {
  podman volume rm -f "$CLAUDE_TOOLBOX_VOLUME" "$CLAUDE_TOOLBOX_VOLUME_JSON"
}
