# Claude container settings isolation — spec

Assembled from the resolved [map](map.md) tickets. Goal: stop bind-mounting host `~/.claude` / `~/.claude.json` into the Claude container; use a container-only podman named volume instead, while keeping build-time-baked plugins/skills from being shadowed by it.

## Current state

- `.containers/claude/Dockerfile` installs Claude Code via mise, then bakes plugins: `claude plugin marketplace add mattpocock/skills` + `claude plugin install mattpocock-skills@mattpocock`, writing under `/home/claude-user/.claude`.
- `dot_oh-my-zsh/custom/executable_claude.zsh`'s `claude-toolbox()` bind-mounts host `~/.claude` and `~/.claude.json` into the container, which shadows whatever was baked in at build time.

## Target design

### 1. Dockerfile — bake plugins outside `$HOME`

Add a build-only config dir, outside the path any runtime volume will cover:

```dockerfile
ENV CLAUDE_CONFIG_DIR_BAKE=/opt/claude-config-baked
RUN mkdir -p ${CLAUDE_CONFIG_DIR_BAKE} && chown claude-user:claude-user ${CLAUDE_CONFIG_DIR_BAKE}
RUN CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR_BAKE} claude plugin marketplace add mattpocock/skills \
    && CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR_BAKE} claude plugin install mattpocock-skills@mattpocock
```

This produces `/opt/claude-config-baked/plugins/{cache,marketplaces,known_marketplaces.json}` and a `settings.json` carrying `enabledPlugins`/`extraKnownMarketplaces`, entirely inside the image layer — [ticket 01](issues/01-config-layout-research.md).

Do **not** set `CLAUDE_CONFIG_DIR` as a persistent runtime `ENV` — the running container uses the default `~/.claude` / `~/.claude.json`, which the volume covers.

### 2. Entrypoint (`setup-and-run-claude.sh`) — reconcile on every start

Before invoking `claude`:

```bash
# Always point plugins at the current image's baked copy, regardless of volume staleness
rm -rf /home/claude-user/.claude/plugins
ln -s /opt/claude-config-baked/plugins /home/claude-user/.claude/plugins

# Merge just the plugin-registration keys into the live (volume-backed) settings.json,
# leaving everything else (permissions/theme/hooks) untouched
jq -s '.[0] * {enabledPlugins: .[1].enabledPlugins, extraKnownMarketplaces: .[1].extraKnownMarketplaces}' \
  /home/claude-user/.claude/settings.json /opt/claude-config-baked/settings.json \
  > /home/claude-user/.claude/settings.json.tmp \
  && mv /home/claude-user/.claude/settings.json.tmp /home/claude-user/.claude/settings.json
```

(Handle the first-ever run, where `settings.json` doesn't exist yet, by seeding it from the baked copy directly.) This runs every start, so a rebuilt image's new plugin version reaches a pre-existing volume automatically — no reset needed for plugin updates. Full rationale: [ticket 04](issues/04-reconciliation-strategy.md).

Everything else under `~/.claude` (`projects/*.jsonl` session transcripts, `history.jsonl`, `.credentials.json`, `CLAUDE.md`, `~/.claude.json` MCP/trust state) stays live and volume-backed, no special handling needed.

### 3. `claude-toolbox()` — swap the bind-mount for a named volume

```zsh
claude-toolbox() {
  DOTFILES_DIR="${HOME}/.local/share/chezmoi"
  IMAGE_NAME="claude-toolbox:latest"
  VOLUME_NAME="claude-toolbox-config"
  if ! podman image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    podman build \
      -t "$IMAGE_NAME" \
      --build-arg USER_ID="$(id -u)" \
      --build-arg GROUP_ID="$(id -g)" \
      "$DOTFILES_DIR/.containers/claude"
  fi
  podman volume create "$VOLUME_NAME" >/dev/null 2>&1 || true
  podman run \
    -it \
    --rm \
    --userns=keep-id \
    -v "$PWD:/workspace/$(basename "$PWD"):rw" \
    -v "${VOLUME_NAME}:/home/claude-user/.claude:rw" \
    --workdir "/workspace/$(basename "$PWD")" \
    --env TERM="${TERM:-xterm-256color}" \
    claude-toolbox:latest
}
```

Single **global** named volume (`claude-toolbox-config`) shared across every project run via `claude-toolbox` — matches today's behavior, avoids duplicating credentials/plugin cache per project. [Ticket 03](issues/03-volume-granularity.md).

Host `~/.claude.json` bind-mount is dropped entirely; no host file is shared with the container anymore.

### 4. Auth — no host credential sharing, re-auth once per volume

First run after switching: no browser needed inside the container — `claude` falls back to a paste-URL/paste-code flow (opened on the host, pasted into the container's TTY). Subsequent runs reuse the credentials persisted in the volume-backed `~/.claude/.credentials.json`, no repeated login. Full detail (including the headless `CLAUDE_CODE_OAUTH_TOKEN` / `ANTHROPIC_API_KEY` alternatives, if a fully non-interactive path is ever wanted): [ticket 02](issues/02-auth-in-container-research.md).

### 5. New `claude-toolbox-reset()` — independent from rebuilding the image

```zsh
claude-toolbox-reset() {
  podman volume rm -f claude-toolbox-config
}
```

`claude-toolbox-new()` stays as-is (rebuilds the image only). Wiping the volume (fresh credentials/session history) and rebuilding the image are independent concerns — rebuilding never forces a re-login. [Ticket 05](issues/05-reset-rebuild-ux.md).

### 6. Permissions — verified, no fixup needed

A fresh podman named volume, mounted with no other change to `--userns=keep-id` and the existing baked-UID `claude-user` account, auto-chowns to the running container user on first use and is immediately writable — confirmed empirically. [Ticket 06](issues/06-podman-volume-permissions.md).

## Migration note

Existing host `~/.claude` data is not imported — the volume starts empty and the user re-authenticates once. (Not separately ticketed; folds into the reset/first-run behavior above.)
