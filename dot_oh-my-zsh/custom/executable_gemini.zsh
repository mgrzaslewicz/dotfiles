
gemini-toolbox() {
  DOTFILES_DIR="${HOME}/.local/share/chezmoi"
  IMAGE_NAME="gemini-toolbox:latest"
  if ! podman image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    podman build \
      -t "$IMAGE_NAME" \
      --build-arg USER_ID="$(id -u)" \
      --build-arg GROUP_ID="$(id -g)" \
      "$DOTFILES_DIR/.containers/gemini"
  fi
  mkdir -p "${HOME}/.gemini"
  podman run \
    -it \
    --rm \
    --userns=keep-id \
    -v "$PWD:/workspace:rw" \
    -v "${HOME}/.gemini:/home/gemini-user/.gemini" \
    --env TERM="${TERM:-xterm-256color}" \
    gemini-toolbox:latest
}

gemini-toolbox-new () {
  podman image rm gemini-toolbox:latest
  gemini-toolbox
}
