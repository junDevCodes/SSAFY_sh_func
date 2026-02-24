#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/algo_functions.sh"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

export HOME="$TEST_HOME"

# shellcheck source=/dev/null
source "$SCRIPT_PATH" >/dev/null 2>&1

output="$(ssafy_algo_help)"

echo "$output" | grep -q "algo-help"
echo "$output" | grep -q "gitup"
echo "$output" | grep -q "https://jundevcodes.github.io/SSAFY_sh_func/guide.html"
echo "$output" | grep -q "https://jundevcodes.github.io/SSAFY_sh_func/alias.html"

echo "PASS: algo-help summary output"
