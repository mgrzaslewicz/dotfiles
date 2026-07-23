
CLAUDE_TOOLBOX_VOLUME="claude-toolbox-config"
CLAUDE_TOOLBOX_VOLUME_JSON="claude-toolbox-config-json"
CLAUDE_TOOLBOX_VOLUME_MISE="claude-toolbox-mise"

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
  podman volume create "$CLAUDE_TOOLBOX_VOLUME_MISE" >/dev/null 2>&1 || true

  # Git identity resolved per-$PWD on the host (not --global) so includeIf-based
  # per-repo identity (e.g. work vs personal email) resolves the same way it
  # would if you ran git in this directory yourself, then passed in as env vars
  # -- git honors these directly, no ~/.gitconfig mount needed. That matters
  # because the real ~/.gitconfig also carries host-only stuff (core.sshCommand
  # pointing at a specific key, signing config) that has no business in the
  # container. Missing values are just omitted; commit fails with git's own
  # "author identity unknown" error, same as today (decision trace:
  # .scratch/claude-container-git-ssh-access/).
  GIT_ENV_ARGS=()
  GIT_AUTHOR_NAME="$(git -C "$PWD" config --get user.name 2>/dev/null || true)"
  GIT_AUTHOR_EMAIL="$(git -C "$PWD" config --get user.email 2>/dev/null || true)"
  if [ -n "$GIT_AUTHOR_NAME" ]; then
    GIT_ENV_ARGS+=(--env "GIT_AUTHOR_NAME=$GIT_AUTHOR_NAME" --env "GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME")
  fi
  if [ -n "$GIT_AUTHOR_EMAIL" ]; then
    GIT_ENV_ARGS+=(--env "GIT_AUTHOR_EMAIL=$GIT_AUTHOR_EMAIL" --env "GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL")
  fi

  # SSH access: forward the host's running ssh-agent socket rather than mounting
  # ~/.ssh private keys. This is an LLM agent with file read/write access --
  # raw key bytes in the container filesystem would be a one-command
  # exfiltration risk for as long as the key is valid. Agent forwarding exposes
  # only a live signing channel over already-loaded keys; there's no key
  # material to steal, and it dies with the container or the host agent
  # session. Only forwarded if the host actually has one live at launch.
  #
  # ~/.ssh/config and known_hosts carry no secret material (aliases, host key
  # fingerprints) so they're mounted read-only when present. GIT_SSH_COMMAND
  # layers a second, container-writable known_hosts on top (so new hosts get
  # accepted+persisted without ever touching the host's real file) and, since
  # it has top precedence over core.sshCommand, also neutralizes any
  # repo/global override that references a host-only key path -- git falls
  # back to whatever the forwarded agent offers instead.
  SSH_MOUNT_ARGS=()
  # Skipped on macOS: podman machine runs containers in a Linux VM behind
  # virtiofs, which can't bind-mount macOS's launchd-activated ssh-agent
  # socket (statfs fails on the dynamic /var/run/com.apple.launchd.*/Listeners
  # path) -- attempting it fails the whole container start, not just SSH
  # access. Same "degrade silently" precedent as an absent socket: container
  # still starts, just without git SSH auth (decision trace:
  # .scratch/claude-container-git-ssh-access/).
  if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ] && [ "$(uname -s)" != "Darwin" ]; then
    SSH_MOUNT_ARGS+=(-v "${SSH_AUTH_SOCK}:/tmp/ssh-agent.sock:rw" --env SSH_AUTH_SOCK=/tmp/ssh-agent.sock)
  fi
  if [ -f "${HOME}/.ssh/config" ]; then
    SSH_MOUNT_ARGS+=(-v "${HOME}/.ssh/config:/home/claude-user/.ssh/config:ro")
  fi
  if [ -f "${HOME}/.ssh/known_hosts" ]; then
    SSH_MOUNT_ARGS+=(-v "${HOME}/.ssh/known_hosts:/home/claude-user/.ssh/known_hosts:ro")
  fi
  SSH_MOUNT_ARGS+=(--env "GIT_SSH_COMMAND=ssh -o UserKnownHostsFile=/home/claude-user/.ssh/known_hosts:/home/claude-user/.ssh/known_hosts.local -o StrictHostKeyChecking=accept-new")

  podman run \
    -it \
    --rm \
    --userns=keep-id \
    -v "$PWD:/workspace/$(basename "$PWD"):rw" \
    -v "${CLAUDE_TOOLBOX_VOLUME}:/home/claude-user/.claude:rw" \
    -v "${CLAUDE_TOOLBOX_VOLUME_JSON}:/home/claude-user/.claude-json-dir:rw" \
    -v "${CLAUDE_TOOLBOX_VOLUME_MISE}:/opt/mise:rw" \
    "${GIT_ENV_ARGS[@]}" \
    "${SSH_MOUNT_ARGS[@]}" \
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

# Independent from claude-toolbox-reset(): wipes only project-installed extra
# toolchains (e.g. `mise use java@21`), not Claude's own auth/session/config.
claude-toolbox-reset-tools () {
  podman volume rm -f "$CLAUDE_TOOLBOX_VOLUME_MISE"
}
