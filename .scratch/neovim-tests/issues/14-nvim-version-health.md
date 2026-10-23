# Tested nvim version in config, `:checkhealth` warning on mismatch

Type: task
Status: open
Blocked by: 02

## What

Host nvim is not controlled by the repo (`mise.toml` is chezmoi-ignored). Make drift visible.

- Constant with the tested nvim version in the deployed config (e.g. `lua/custom/health.lua`).
- `:checkhealth custom`: OK when `vim.version()` matches, WARN otherwise (no startup notification).
- Test: constant equals the version the tests run on (repo `mise.toml` pin), so bumping the pin fails
  until the constant is updated.

## Acceptance

- Test fails after changing only the `mise.toml` neovim pin.
- `:checkhealth custom` in a matching nvim reports OK; in a child nvim with the version faked/mismatched, WARN.
