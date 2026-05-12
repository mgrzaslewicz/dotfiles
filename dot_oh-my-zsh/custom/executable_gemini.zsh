
gemini() {
  DOTFILES_DIR="${HOME}/.local/share/chezmoi"
  IMAGE_NAME="gemini-toolbox:latest"
  if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    docker build \
      -t "$IMAGE_NAME" \
      "$DOTFILES_DIR/containers/gemini"
  fi
  mkdir -p "${HOME}/gemini"
  docker run \
    -it \
    --rm \
    -v "$PWD:/workspace:rw" \
    -v "${HOME}/.gemini:/home/gemini-user/.gemini" \
    --env TERM="${TERM:-xterm-256color}" \
    gemini-toolbox:latest
}
