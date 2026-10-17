#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
NVIM_LOG_FILE="$test_dir/nvim.log" XDG_DATA_HOME="$test_dir/data" XDG_STATE_HOME="$test_dir/state" XDG_CACHE_HOME="$test_dir/cache" \
  nvim --headless -u NONE -i NONE -l tests/regression.lua
