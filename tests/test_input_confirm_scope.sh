#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT_DIR/lib/input.sh"

pass_count=0
fail_count=0

pass() { echo "PASS: $1"; pass_count=$((pass_count + 1)); }
fail() { echo "FAIL: $1"; fail_count=$((fail_count + 1)); }

run_test() {
  local name="$1"
  shift
  if "$@"; then
    pass "$name"
  else
    fail "$name"
  fi
}

test_non_interactive_default_yes_sets_caller_var() {
  local answer=""
  _is_interactive() { return 1; }
  input_confirm answer "Proceed?" "y"
  [ "$answer" = "yes" ]
}

test_non_interactive_default_no_sets_caller_var() {
  local answer=""
  _is_interactive() { return 1; }
  input_confirm answer "Proceed?" "n"
  [ "$answer" = "no" ]
}

run_test "input_confirm sets caller var to yes in non-interactive mode" test_non_interactive_default_yes_sets_caller_var
run_test "input_confirm sets caller var to no in non-interactive mode" test_non_interactive_default_no_sets_caller_var

echo ""
echo "Tests: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
