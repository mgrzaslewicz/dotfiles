# Tested nvim version in config, `:checkhealth` warning on mismatch

Type: task
Status: resolved
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

## Notes

- `lua/custom/health.lua`: `tested_version` and `check()`. Compares major.minor.patch plus prerelease; build
  metadata (`tostring(vim.version())` gives `0.12.6+v0.12.6`) is ignored.
- WARN advice: `mise use -g neovim@<tested>`, or move the pin (mise.toml + `tested_version`) and run the check.
- `tests/test_health.lua`: the constant and the running nvim equal the `mise.toml` pin; checkhealth OK on the
  tested version, WARN with the constant faked to `0.11.0`.
- Verified: pin bumped to 0.12.5 alone fails 2 cases (constant mismatch; checkhealth no longer OK). A pin to a
  non-existent version fails earlier, in mise install.
