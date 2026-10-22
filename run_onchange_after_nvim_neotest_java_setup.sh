#!/bin/bash
set -e

# Downloads the JUnit console launcher jar neotest-java needs (same as running
# `:NeotestJava setup`). Its yes/no prompt is auto-answered with the first
# choice ("Yes, download" / "Yes, upgrade"). Starting nvim also installs any
# missing plugins first. Re-runs whenever the neotest config changes:
# neotest.lua hash: {{ include "dot_config/nvim/lua/custom/plugins/neotest.lua" | sha256sum }}
command -v nvim >/dev/null 2>&1 || exit 0

nvim --headless \
  -c 'lua vim.ui.select = function(choices, _, cb) cb(choices[1]) end' \
  -c 'NeotestJava setup' \
  -c 'qa!'
