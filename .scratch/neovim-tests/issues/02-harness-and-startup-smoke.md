# mini.test harness, NVIM_TEST profile, first smoke test

Type: task
Status: resolved
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

## Notes

- `tests/run.sh` symlinks `tests/.tests/config/nvim` → config root and sets XDG dirs: config and lockfile
  come from the source tree (vim.pack reads the lockfile from `$XDG_CONFIG_HOME/nvim/`).
- mini.test children always get `--clean`, which empties `packpath`; `tests/nvim-child` drops it so children
  start like a real session.
- Profile: `vim.g.test_mode` (from `NVIM_TEST=1`) gates mason-tool-installer, treesitter `install` (startup,
  FileType auto-install, `TSUpdate` on PackChanged). Red run failed with `stylua: failed to install`.
- First run ~7 s (35 plugins, codediff native lib); later runs ~1.2 s.
- No treesitter parsers in the test env: treesitter features are not active in layer A tests.
