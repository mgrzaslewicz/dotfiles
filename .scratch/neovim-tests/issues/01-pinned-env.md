# Pinned, isolated tool and plugin versions

Type: task
Status: resolved

## What

Spec decisions 3, 4, 5.

- Repo `mise.toml`: pin `neovim` (0.12.6), `stylua`, `lua-language-server`.
- `dot_config/nvim/.gitignore`: stop ignoring `nvim-pack-lock.json` and `.luarc.json`;
  ignore `tests/.tests/`.
- Generate and commit `nvim-pack-lock.json` from the current plugin set.
- `.chezmoiignore`: exclude `.config/nvim/tests` (and its `.tests/` state) and `mise.toml`
  (repo pin is for tests only; host versions are managed on the host, see issue 14).

## Acceptance

- `mise install` in a fresh clone provides `nvim`, `stylua`, `lua-language-server` at pinned versions.
- `chezmoi apply --dry-run --verbose` lists no files under `~/.config/nvim/tests`.
- Lockfile committed; installing plugins from it reproduces the same revisions.

## Host follow-up (user)

Switch daily nvim from snap to mise (`mise use -g neovim@<version>`, remove snap); `which nvim` is the mise shim.
Lockfile taken from the host's daily install. After `vim.pack.update()`: `chezmoi re-add ~/.config/nvim/nvim-pack-lock.json`.
