#!/usr/bin/env bash
# Runs the config tests in an isolated environment. Config and nvim-pack-lock.json come from this
# source tree (no `chezmoi apply` needed); plugins, Mason and all state live in the layer's state dir.
#
#   tests/run.sh                         layer A (unit + smoke): all tests/test_*.lua, state in tests/.tests
#   tests/run.sh tests/test_x.lua        one file
#   tests/run.sh --e2e                   layer B (real servers, builds, DAP): tests/e2e/test_*.lua, state in tests/.tests-e2e
#   tests/run.sh --e2e tests/e2e/test_x.lua
set -euo pipefail

cd "$(dirname "$0")/.."
root=$PWD

layer=tests name=.tests
if [ "${1:-}" = --e2e ]; then
  shift
  layer=tests/e2e name=.tests-e2e
fi

# Real state lives in a short per-checkout dir; tests/$name is a symlink to it. Neovim's luac cache file
# names are the escaped plugin paths, which overflow ENAMETOOLONG (255 bytes) under long checkout paths.
short=/tmp/nvim-$name-$(printf %s "$root" | cksum | cut -d " " -f1)
mkdir -p "$short"
if [ -d "$root/tests/$name" ] && [ ! -L "$root/tests/$name" ]; then rm -rf "$root/tests/$name"; fi
ln -sfn "$short" "$root/tests/$name"
state=$(cd "$short" && pwd -P)

mkdir -p "$state/config"
ln -sfn "$root" "$state/config/nvim"
export XDG_CONFIG_HOME=$state/config XDG_DATA_HOME=$state/data XDG_STATE_HOME=$state/state XDG_CACHE_HOME=$state/cache
# Inside a git hook, GIT_INDEX_FILE & co. point at this repo; plugin clones must not inherit them.
unset $(git rev-parse --local-env-vars)

if [ "$layer" = tests ]; then
  export NVIM_TEST=1
  # First run: install plugins at the lockfile's revisions by loading the config once.
  if [ ! -f "$XDG_DATA_HOME/nvim/site/pack/core/opt/mini.nvim/lua/mini/test.lua" ]; then
    nvim --headless +qa
  fi
else
  # Real installs and builds: Mason tools, treesitter parsers, Gradle/Maven caches, all inside the state dir.
  unset NVIM_TEST
  export GRADLE_USER_HOME=$state/gradle MAVEN_ARGS="-Dmaven.repo.local=$state/m2"
  nvim --clean --headless -l tests/e2e/preflight.lua
  # Installs what is missing (plugins, pinned Mason packages, parsers) and checks the result; fast when up to date.
  nvim --headless -c 'luafile tests/e2e/bootstrap.lua'
fi

# Any error outside a test case would leave headless nvim running; turn it into a failed run.
# Headless nvim treats SIGINT as an interrupt, not a reason to exit, so Ctrl-C is forwarded as SIGTERM.
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "lua local ok, err = pcall(function() require('tests.helpers').run('$layer', '${1:-}') end) if not ok then io.stderr:write(err, '\\n') vim.cmd 'cquit 1' end" &
runner=$!
trap 'kill -TERM "$runner" 2>/dev/null; exit 130' INT TERM
wait "$runner"
