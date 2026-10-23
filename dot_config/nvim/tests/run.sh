#!/usr/bin/env bash
# Runs the config tests in an isolated environment. Config and nvim-pack-lock.json come from this
# source tree (no `chezmoi apply` needed); plugins, Mason and all state live in tests/.tests/.
#
#   tests/run.sh                    all tests
#   tests/run.sh tests/test_x.lua   one file
set -euo pipefail

cd "$(dirname "$0")/.."
root=$PWD
state=$root/tests/.tests

mkdir -p "$state/config"
ln -sfn "$root" "$state/config/nvim"
export XDG_CONFIG_HOME=$state/config XDG_DATA_HOME=$state/data XDG_STATE_HOME=$state/state XDG_CACHE_HOME=$state/cache
export NVIM_TEST=1

# First run: install plugins at the lockfile's revisions by loading the config once.
if [ ! -d "$XDG_DATA_HOME/nvim/site/pack/core/opt/mini.nvim" ]; then
  nvim --headless +qa
fi

nvim --headless --noplugin -u tests/minimal_init.lua -c "lua require('tests.helpers').run('${1:-}')"
