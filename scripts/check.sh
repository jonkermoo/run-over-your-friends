#!/usr/bin/env bash
# The 4 checks. All must pass before Studio sees anything. Works empty.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f roblox.yml ] || selene generate-roblox-std >/dev/null

echo "== 1/4 rojo build"
mkdir -p build
rojo build -o build/game.rbxl

echo "== 2/4 tests"
lune run tests/run

echo "== 3/4 selene"
selene src tests

echo "== 4/4 stylua"
stylua --check src tests

echo "ALL CHECKS PASSED"
