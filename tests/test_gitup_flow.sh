#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/algo_functions.sh"

if command -v mktemp >/dev/null 2>&1; then
  TEST_ROOT="$(mktemp -d)"
else
  TEST_ROOT="$ROOT_DIR/.tmp_gitup_flow_$$"
  mkdir -p "$TEST_ROOT"
fi
cleanup() {
  cd "$ROOT_DIR" || true
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

cat > "$HOME/.algo_config" <<'EOF'
ALGO_BASE_DIR="$HOME/algos"
GIT_DEFAULT_BRANCH="main"
GIT_COMMIT_PREFIX="solve"
GIT_AUTO_PUSH=false
IDE_EDITOR="code"
SSAFY_BASE_URL="https://lab.ssafy.com"
SSAFY_USER_ID="testuser"
EOF

# shellcheck source=/dev/null
source "$SCRIPT_PATH" >/dev/null 2>&1

pass_count=0
fail_count=0

pass() {
  echo "PASS: $1"
  pass_count=$((pass_count + 1))
}

fail() {
  echo "FAIL: $1"
  fail_count=$((fail_count + 1))
}

run_test() {
  local name="$1"
  shift
  if "$@"; then
    pass "$name"
  else
    fail "$name"
  fi
}

stub_common() {
  ui_header() { :; }
  ui_info() { :; }
  ui_warn() { :; }
}

test_step3_preview_text() {
  local header_title=""
  local header_subtitle=""
  local info_lines=()

  ui_panel_begin() {
    header_title="$1"
    header_subtitle="${2:-}"
  }
  ui_header() {
    header_title="$1"
    header_subtitle="${2:-}"
  }
  ui_info() {
    info_lines+=("$1")
  }
  ui_warn() { :; }

  input_choice() {
    printf -v "$1" '%s' "2"
    return 0
  }
  input_text() {
    printf -v "$1" '%s' "https://github.com/octocat/Hello-World.git"
    return 0
  }
  input_masked() { return 1; }
  input_confirm() {
    printf -v "$1" '%s' "yes"
    return 0
  }

  _ssafy_gitup_prompt_flow
  local rc=$?
  [ "$rc" -eq 0 ] || return 1
  [ "$header_title" = "gitup" ] || return 1
  [ "$header_subtitle" = "Step 3/4: Preview before run" ] || return 1

  local found_mode=0
  local found_estimate=0
  local line=""
  for line in "${info_lines[@]}"; do
    [ "$line" = "Input mode=URL" ] && found_mode=1
    case "$line" in
      "Estimated repos="*) found_estimate=1 ;;
    esac
  done
  [ "$found_mode" -eq 1 ] || return 1
  [ "$found_estimate" -eq 1 ] || return 1
}

test_step4_yes_returns_ok() {
  stub_common
  local choice_calls=0
  local text_calls=0
  local confirm_calls=0

  input_choice() {
    choice_calls=$((choice_calls + 1))
    printf -v "$1" '%s' "2"
    return 0
  }
  input_text() {
    text_calls=$((text_calls + 1))
    printf -v "$1" '%s' "https://github.com/octocat/Hello-World.git"
    return 0
  }
  input_masked() { return 1; }
  input_confirm() {
    confirm_calls=$((confirm_calls + 1))
    printf -v "$1" '%s' "yes"
    return 0
  }

  _ssafy_gitup_prompt_flow
  local rc=$?
  [ "$rc" -eq 0 ] || return 1
  [ "${SSAFY_GITUP_FLOW_MODE:-}" = "2" ] || return 1
  [ "${SSAFY_GITUP_FLOW_INPUT:-}" = "https://github.com/octocat/Hello-World.git" ] || return 1
  [ "$confirm_calls" -eq 1 ] || return 1
}

test_step4_back_returns_to_step2() {
  stub_common
  local text_calls=0
  local confirm_calls=0

  input_choice() {
    printf -v "$1" '%s' "2"
    return 0
  }
  input_text() {
    text_calls=$((text_calls + 1))
    if [ "$text_calls" -eq 1 ]; then
      printf -v "$1" '%s' "https://github.com/first/repo.git"
    else
      printf -v "$1" '%s' "https://github.com/second/repo.git"
    fi
    return 0
  }
  input_masked() { return 1; }
  input_confirm() {
    confirm_calls=$((confirm_calls + 1))
    if [ "$confirm_calls" -eq 1 ]; then
      printf -v "$1" '%s' "yes"
      return 10
    fi
    printf -v "$1" '%s' "yes"
    return 0
  }

  _ssafy_gitup_prompt_flow
  local rc=$?
  [ "$rc" -eq 0 ] || return 1
  [ "$text_calls" -eq 2 ] || return 1
  [ "${SSAFY_GITUP_FLOW_INPUT:-}" = "https://github.com/second/repo.git" ] || return 1
}

test_step2_invalid_then_retry() {
  stub_common
  local text_calls=0

  input_choice() {
    printf -v "$1" '%s' "2"
    return 0
  }
  input_text() {
    text_calls=$((text_calls + 1))
    if [ "$text_calls" -eq 1 ]; then
      printf -v "$1" '%s' "invalid-url"
    else
      printf -v "$1" '%s' "https://github.com/valid/repo.git"
    fi
    return 0
  }
  input_masked() { return 1; }
  input_confirm() {
    printf -v "$1" '%s' "yes"
    return 0
  }

  _ssafy_gitup_prompt_flow
  local rc=$?
  [ "$rc" -eq 0 ] || return 1
  [ "$text_calls" -eq 2 ] || return 1
}

test_step1_cancel() {
  stub_common
  input_choice() {
    printf -v "$1" '%s' "1"
    return 20
  }
  input_text() { return 1; }
  input_masked() { return 1; }
  input_confirm() { return 1; }

  _ssafy_gitup_prompt_flow
  local rc=$?
  [ "$rc" -eq 20 ]
}

test_step4_no_returns_cancel() {
  stub_common
  input_choice() {
    printf -v "$1" '%s' "2"
    return 0
  }
  input_text() {
    printf -v "$1" '%s' "https://github.com/valid/repo.git"
    return 0
  }
  input_masked() { return 1; }
  input_confirm() {
    printf -v "$1" '%s' "no"
    return 0
  }

  _ssafy_gitup_prompt_flow
  local rc=$?
  [ "$rc" -eq 20 ]
}

test_debug_logs_show_return_values() {
  local output=""
  local rc=0

  ui_header() { :; }
  ui_info() { :; }
  ui_warn() { :; }

  input_choice() {
    printf -v "$1" '%s' "2"
    return 0
  }
  input_text() {
    printf -v "$1" '%s' "https://github.com/octocat/Hello-World.git"
    return 0
  }
  input_masked() { return 1; }
  input_confirm() {
    printf -v "$1" '%s' "yes"
    return 0
  }

  output="$(SSAFY_DEBUG_FLOW=1 _ssafy_gitup_prompt_flow 2>&1)" || rc=$?
  [ "${rc:-0}" -eq 0 ] || return 1

  echo "$output" | grep -q "\[DEBUG\]\[gitup\] step=1 rc=0 mode=2"
  echo "$output" | grep -q "\[DEBUG\]\[gitup\] step=2 mode=URL rc=0 input=https://github.com/octocat/Hello-World.git"
  echo "$output" | grep -q "\[DEBUG\]\[gitup\] step=4 rc=0 answer=yes"
  echo "$output" | grep -q "\[DEBUG\]\[gitup\] step=4 resolved=ok mode=2 input=https://github.com/octocat/Hello-World.git"
}

run_test "gitup step4 yes returns ok" test_step4_yes_returns_ok
run_test "gitup step3 preview text is readable" test_step3_preview_text
run_test "gitup step4 back returns to step2" test_step4_back_returns_to_step2
run_test "gitup step2 invalid then retry" test_step2_invalid_then_retry
run_test "gitup step1 cancel returns 20" test_step1_cancel
run_test "gitup step4 no returns cancel" test_step4_no_returns_cancel
run_test "gitup debug logs show return values" test_debug_logs_show_return_values

echo ""
echo "Tests: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
