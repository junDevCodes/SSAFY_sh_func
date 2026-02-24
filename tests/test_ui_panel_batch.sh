#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/algo_functions.sh"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

export HOME="$TEST_HOME"
export ALGO_UI_STYLE=panel
export ALGO_UI_RENDERER=python

# shellcheck source=/dev/null
source "$SCRIPT_PATH" >/dev/null 2>&1

output="$(ssafy_algo_config show)"

echo "$output" | grep -q "algo-config"
echo "$output" | grep -q "설정 요약"
echo "$output" | grep -q "ALGO_BASE_DIR"
echo "$output" | grep -q "GIT_DEFAULT_BRANCH"

echo "PASS: panel render output"
