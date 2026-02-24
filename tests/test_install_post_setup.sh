#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT_DIR/install.sh"

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

test_has_gui_first_setup_flow() {
  grep -q 'Starting post-install setup (GUI wizard)' "$TARGET"
  grep -q 'wizard_path="\$INSTALL_DIR/algo_config_wizard.py"' "$TARGET"
}

test_has_cli_fallback_on_gui_failure() {
  grep -q '^post_install_setup_cli()' "$TARGET"
  grep -q 'post_install_setup_cli' "$TARGET"
  grep -q 'GUI setup failed or canceled' "$TARGET"
}

test_optional_defaults_are_kept() {
  grep -q 'set_config_value "SSAFY_UPDATE_CHANNEL"' "$TARGET"
  grep -q 'set_config_value "ALGO_UI_STYLE" "panel"' "$TARGET"
  grep -q 'set_config_value "ALGO_UI_COLOR" "auto"' "$TARGET"
  grep -q 'set_config_value "ALGO_INPUT_PROFILE" "stable"' "$TARGET"
}

run_test "install has GUI-first post setup" test_has_gui_first_setup_flow
run_test "install has CLI fallback when GUI fails" test_has_cli_fallback_on_gui_failure
run_test "install keeps optional defaults" test_optional_defaults_are_kept

echo ""
echo "Tests: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
