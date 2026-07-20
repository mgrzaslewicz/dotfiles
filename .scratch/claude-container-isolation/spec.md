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

Do set `CLAUDE_CODE_PLUGIN_SEED_DIR=${CLAUDE_CONFIG_DIR_BAKE}/plugins` as a persistent runtime `ENV`, unlike `CLAUDE_CONFIG_DIR`. It's a read-only, additive seed path by design — Claude Code registers its marketplaces/plugin cache into the live config on every startup itself, so this replaces the plugins-symlink and the `extraKnownMarketplaces` half of the old merge script entirely. No jq/git logic needed for that part; see below.

### 2. Entrypoint (`setup-and-run-claude.sh`) — reconcile `enabledPlugins` on every start

`CLAUDE_CODE_PLUGIN_SEED_DIR` (above) handles marketplace/plugin-cache registration on its own. `enabledPlugins` isn't covered by the seed dir, so it's the one thing the entrypoint still reconciles, before invoking `claude`:

```bash
# ~/.claude.json lives directly under $HOME, not under ~/.claude, so it needs
# its own volume-backed directory; symlink the expected path into it.
if [ ! -L "${HOME}/.claude.json" ]; then
  rm -f "${HOME}/.claude.json"
  ln -s "${HOME}/.claude-json-dir/.claude.json" "${HOME}/.claude.json"
fi

# Add any baked-in plugin missing from the live settings.json. '+' on
# enabledPlugins is a per-key union where the live side wins on conflicts, so
# a plugin the user has since disabled/reconfigured stays untouched — this
# only fills gaps, it never does a wholesale merge of the two settings files.
jq -s '.[0] + {enabledPlugins: ((.[1].enabledPlugins // {}) + (.[0].enabledPlugins // {}))}' \
  /home/claude-user/.claude/settings.json /opt/claude-config-baked/settings.json \
  > /home/claude-user/.claude/settings.json.tmp \
  && mv /home/claude-user/.claude/settings.json.tmp /home/claude-user/.claude/settings.json
```

(Handle the first-ever run, where `settings.json` doesn't exist yet, by seeding it with just `{enabledPlugins: ...}` from the baked copy, not the whole baked file — the rest of the baked settings.json is build-time noise now that the seed dir owns marketplace registration.) This runs every start, so a rebuilt image's new plugin reaches a pre-existing volume automatically — no reset needed for plugin updates. Considered and rejected: reimplementing this as a `git merge` over a versioned `~/.claude` — no repo/history exists today, and it would trade one tool-specific hack (jq keys) for a heavier one (a real git repo, conflict resolution at non-interactive startup) to solve a problem the seed dir already solves natively. Original rationale for the two-key jq approach: [ticket 04](issues/04-reconciliation-strategy.md) (superseded by this section for the marketplace half).

Everything else under `~/.claude` (`projects/*.jsonl` session transcripts, `history.jsonl`, `.credentials.json`, `CLAUDE.md`) stays live and volume-backed with no special handling. `~/.claude.json` (MCP config, per-project trust state) needs a **second** named volume, since it's a file directly under `$HOME` rather than inside `~/.claude/` — see §3.

### 3. `claude-toolbox()` — swap the bind-mount for a named volume

```zsh
claude-toolbox() {
  DOTFILES_DIR="${HOME}/.local/share/chezmoi"
  IMAGE_NAME="claude-toolbox:latest"
  VOLUME_NAME="claude-toolbox-config"
  VOLUME_JSON_NAME="claude-toolbox-config-json"
  if ! podman image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    podman build \
      -t "$IMAGE_NAME" \
      --build-arg USER_ID="$(id -u)" \
      --build-arg GROUP_ID="$(id -g)" \
      "$DOTFILES_DIR/.containers/claude"
  fi
  podman volume create "$VOLUME_NAME" >/dev/null 2>&1 || true
  podman volume create "$VOLUME_JSON_NAME" >/dev/null 2>&1 || true
  podman run \
    -it \
    --rm \
    --userns=keep-id \
    -v "$PWD:/workspace/$(basename "$PWD"):rw" \
    -v "${VOLUME_NAME}:/home/claude-user/.claude:rw" \
    -v "${VOLUME_JSON_NAME}:/home/claude-user/.claude-json-dir:rw" \
    --workdir "/workspace/$(basename "$PWD")" \
    --env TERM="${TERM:-xterm-256color}" \
    claude-toolbox:latest
}
```

Two **global** named volumes (`claude-toolbox-config`, `claude-toolbox-config-json`) shared across every project run via `claude-toolbox` — matches today's behavior, avoids duplicating credentials/plugin cache per project. [Ticket 03](issues/03-volume-granularity.md). Two volumes rather than one because `~/.claude.json` is a file directly under `$HOME`, not something a directory-mounted volume at `~/.claude` can also cover; the entrypoint symlinks it into the second volume (mounted as a directory, since podman named volumes mount as directories, not single files).

Host `~/.claude.json` bind-mount is dropped entirely; no host file is shared with the container anymore.

### 4. Auth — no host credential sharing, re-auth once per volume

First run after switching: no browser needed inside the container — `claude` falls back to a paste-URL/paste-code flow (opened on the host, pasted into the container's TTY). Subsequent runs reuse the credentials persisted in the volume-backed `~/.claude/.credentials.json`, no repeated login. Full detail (including the headless `CLAUDE_CODE_OAUTH_TOKEN` / `ANTHROPIC_API_KEY` alternatives, if a fully non-interactive path is ever wanted): [ticket 02](issues/02-auth-in-container-research.md).

### 5. New `claude-toolbox-reset()` — independent from rebuilding the image

```zsh
claude-toolbox-reset() {
  podman volume rm -f claude-toolbox-config claude-toolbox-config-json
}
```

`claude-toolbox-new()` stays as-is (rebuilds the image only). Wiping the volume (fresh credentials/session history) and rebuilding the image are independent concerns — rebuilding never forces a re-login. [Ticket 05](issues/05-reset-rebuild-ux.md).

### 6. Permissions — verified, no fixup needed

A fresh podman named volume, mounted with no other change to `--userns=keep-id` and the existing baked-UID `claude-user` account, auto-chowns to the running container user on first use and is immediately writable — confirmed empirically. [Ticket 06](issues/06-podman-volume-permissions.md).

## Migration note

Existing host `~/.claude` data is not imported — the volume starts empty and the user re-authenticates once. (Not separately ticketed; folds into the reset/first-run behavior above.)
