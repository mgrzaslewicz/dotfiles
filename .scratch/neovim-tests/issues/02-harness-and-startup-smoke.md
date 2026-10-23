# mini.test harness, NVIM_TEST profile, first smoke test

Type: task
Status: open
Blocked by: 01

## What

Spec decisions 2, 5, 8; slice 1 items 2–4 (startup part).

- `tests/minimal_init.lua`: XDG dirs → `tests/.tests/`, rtp at the source tree, mini.test bootstrap.
- Child-nvim helper that starts nvim with `-u dot_config/nvim/init.lua` and `NVIM_TEST=1`.
- `NVIM_TEST=1` in `init.lua`: skip mason-tool-installer and treesitter auto-installs.
- `mise run test` task (`nvim --headless … -c "lua MiniTest.run()"`), non-zero exit on failure.
- Test-first: write the startup smoke test before the profile — it must fail (Mason install attempt / errors) first.

## Acceptance

- `tests/test_startup.lua`: full config loads in a child nvim with no errors and empty `:messages`
  (allowlist only if unavoidable, with a comment why).
- No network access after the first bootstrap; no Mason package installed under `tests/.tests/`.
- Second `mise run test` run completes in < 10 s.
