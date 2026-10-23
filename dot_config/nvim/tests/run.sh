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
# Inside a git hook, GIT_INDEX_FILE & co. point at this repo; plugin clones must not inherit them.
unset $(git rev-parse --local-env-vars)

# First run: install plugins at the lockfile's revisions by loading the config once.
if [ ! -f "$XDG_DATA_HOME/nvim/site/pack/core/opt/mini.nvim/lua/mini/test.lua" ]; then
  nvim --headless +qa
fi

# Any error outside a test case would leave headless nvim running; turn it into a failed run.
# Headless nvim treats SIGINT as an interrupt, not a reason to exit, so Ctrl-C is forwarded as SIGTERM.
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "lua local ok, err = pcall(function() require('tests.helpers').run('${1:-}') end) if not ok then io.stderr:write(err, '\\n') vim.cmd 'cquit 1' end" &
runner=$!
trap 'kill -TERM "$runner" 2>/dev/null; exit 130' INT TERM
wait "$runner"
