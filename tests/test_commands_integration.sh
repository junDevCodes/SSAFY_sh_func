#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/algo_functions.sh"

if command -v mktemp >/dev/null 2>&1; then
  TEST_ROOT="$(mktemp -d)"
else
  TEST_ROOT="$ROOT_DIR/.tmp_integration_$$"
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
ALGO_BASE_DIR="$HOME/algo_workspace"
GIT_DEFAULT_BRANCH="main"
GIT_COMMIT_PREFIX="solve"
GIT_AUTO_PUSH=false
IDE_EDITOR="code"
SSAFY_BASE_URL="https://lab.ssafy.com"
SSAFY_USER_ID="testuser"
EOF

mkdir -p "$HOME/algo_workspace"

# shellcheck source=/dev/null
source "$SCRIPT_PATH" >/dev/null 2>&1

pass_count=0
fail_count=0
step_count=0

print_step() {
  step_count=$((step_count + 1))
  echo ""
  echo "[$step_count] $1"
}

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
  print_step "$name"
  if "$@"; then
    pass "$name"
  else
    fail "$name"
  fi
}

assert_file_exists() {
  local path="$1"
  [ -f "$path" ] || {
    echo "  expected file: $path"
    return 1
  }
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || {
    echo "  expected output to include: $needle"
    return 1
  }
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  [ "$actual" = "$expected" ] || {
    echo "  expected: $expected"
    echo "  actual  : $actual"
    return 1
  }
}

setup_git_stub() {
  __git_clone_called=0
  __git_clone_url=""
  __git_clone_target=""
  __git_commit_called=0
  __git_commit_msg=""
  __git_add_called=0
  __git_push_called=0

  git() {
    local cmd="${1:-}"
    shift || true
    case "$cmd" in
      clone)
        __git_clone_called=$((__git_clone_called + 1))
        __git_clone_url="${1:-}"
        __git_clone_target="$(basename "${__git_clone_url%.git}")"
        mkdir -p "$__git_clone_target"
        return 0
        ;;
      add)
        __git_add_called=$((__git_add_called + 1))
        return 0
        ;;
      commit)
        __git_commit_called=$((__git_commit_called + 1))
        if [ "${1:-}" = "-m" ]; then
          __git_commit_msg="${2:-}"
        fi
        return 0
        ;;
      push)
        __git_push_called=$((__git_push_called + 1))
        return 0
        ;;
      status)
        return 0
        ;;
      branch)
        if [ "${1:-}" = "--list" ]; then
          echo "* main"
          return 0
        fi
        return 0
        ;;
      symbolic-ref|remote|rev-parse)
        return 0
        ;;
      *)
        command git "$cmd" "$@"
        ;;
    esac
  }
}

setup_ui_stub() {
  ui_header() { :; }
  ui_section() { :; }
  ui_info() { :; }
  ui_ok() { :; }
  ui_warn() { :; }
  ui_error() { :; }
  ui_step() { :; }
  ui_hint() { :; }
  ui_path() { :; }
}

test_al_non_interactive_py_flow() {
  setup_ui_stub
  ssafy_al b 2001 py --no-git --no-open >/dev/null 2>&1
  assert_file_exists "$ALGO_BASE_DIR/boj/2001/boj_2001.py"
  assert_file_exists "$ALGO_BASE_DIR/boj/2001/sample_input.txt"
}

test_al_interactive_with_back_and_confirm() {
  setup_ui_stub
  _is_interactive() { return 0; }
  local text_calls=0
  input_choice() {
    case "$2" in
      "Step 1/7: Select site") printf -v "$1" '%s' "b"; return 0 ;;
      "Step 3/7: Select language") printf -v "$1" '%s' "cpp"; return 0 ;;
      *) return 1 ;;
    esac
  }
  input_text() {
    case "$2" in
      "Step 2/7: Enter problem number")
        printf -v "$1" '%s' "2002"
        return 0
        ;;
      "Step 6/7: Commit message (blank for auto)")
        printf -v "$1" '%s' ""
        return 0
        ;;
    esac
    return 1
  }
  input_confirm() {
    case "$2" in
      "Step 4/7: Skip git stage?") printf -v "$1" '%s' "yes"; return 0 ;;
      "Step 5/7: Skip open editor stage?")
        text_calls=$((text_calls + 1))
        if [ "$text_calls" -eq 1 ]; then
          printf -v "$1" '%s' "yes"
          return 10
        fi
        printf -v "$1" '%s' "yes"
        return 0
        ;;
      "Step 7/7: Run now?") printf -v "$1" '%s' "yes"; return 0 ;;
    esac
    return 1
  }

  ssafy_al b >/dev/null 2>&1
  assert_file_exists "$ALGO_BASE_DIR/boj/2002/boj_2002.cpp"
  assert_eq "$text_calls" "2"
}

test_gitup_interactive_url_clone_flow() {
  setup_ui_stub
  setup_git_stub
  _is_interactive() { return 0; }

  _open_repo_file() { return 0; }

  local confirm_calls=0
  input_choice() {
    printf -v "$1" '%s' "2"
    return 0
  }
  input_text() {
    printf -v "$1" '%s' "https://github.com/example/repo.git"
    return 0
  }
  input_confirm() {
    confirm_calls=$((confirm_calls + 1))
    printf -v "$1" '%s' "yes"
    return 0
  }

  ssafy_gitup >/dev/null 2>&1
  assert_eq "$__git_clone_called" "1"
  assert_eq "$__git_clone_url" "https://github.com/example/repo.git"
  assert_eq "$confirm_calls" "1"
}

test_gitup_step4_back_then_success() {
  setup_ui_stub
  setup_git_stub
  _is_interactive() { return 0; }

  _open_repo_file() { return 0; }

  local text_calls=0
  local confirm_calls=0
  input_choice() {
    printf -v "$1" '%s' "2"
    return 0
  }
  input_text() {
    text_calls=$((text_calls + 1))
    if [ "$text_calls" -eq 1 ]; then
      printf -v "$1" '%s' "https://github.com/example/first.git"
    else
      printf -v "$1" '%s' "https://github.com/example/second.git"
    fi
    return 0
  }
  input_confirm() {
    confirm_calls=$((confirm_calls + 1))
    printf -v "$1" '%s' "yes"
    if [ "$confirm_calls" -eq 1 ]; then
      return 10
    fi
    return 0
  }

  ssafy_gitup >/dev/null 2>&1
  assert_eq "$text_calls" "2"
  assert_eq "$__git_clone_url" "https://github.com/example/second.git"
}

test_gitup_smartlink_applies_token_and_calls_batch() {
  setup_ui_stub
  setup_git_stub

  unset SSAFY_AUTH_TOKEN

  local called=0
  local received=""
  ssafy_batch() {
    called=1
    received="$1"
    return 0
  }

  local smart_url="https://project.ssafy.com/practiceroom/course/CS00000000/practice/PR00000000/answer/PA00000000"
  local token_plain="Bearer INTEGRATION_TEST_TOKEN"
  local token_b64=""
  token_b64="$(printf '%s' "$token_plain" | base64 | tr -d '\r\n')"

  ssafy_gitup "${smart_url}|${token_b64}" >/dev/null 2>&1

  assert_eq "$called" "1"
  assert_eq "$received" "$smart_url"
  assert_eq "${SSAFY_AUTH_TOKEN:-}" "$token_plain"
}

test_gitdown_interactive_commit_flow() {
  setup_ui_stub
  setup_git_stub
  _is_interactive() { return 0; }

  input_choice() {
    printf -v "$1" '%s' "custom"
    return 0
  }
  input_text() {
    case "$2" in
      "Step 2/5: Enter commit message")
        printf -v "$1" '%s' "feat: integration flow"
        return 0
        ;;
      *)
        printf -v "$1" '%s' "0"
        return 0
        ;;
    esac
  }
  input_confirm() {
    printf -v "$1" '%s' "yes"
    return 0
  }
  _confirm_commit_message() {
    CONFIRMED_COMMIT_MSG="$1"
    return 0
  }

  ssafy_gitdown >/dev/null 2>&1
  assert_eq "$__git_add_called" "1"
  assert_eq "$__git_commit_called" "1"
  assert_eq "$__git_commit_msg" "feat: integration flow"
}

test_gitdown_all_mode_flow() {
  setup_ui_stub

  local called=0
  _gitdown_all() {
    called=1
    return 0
  }
  input_confirm() {
    printf -v "$1" '%s' "yes"
    return 0
  }

  ssafy_gitdown --all >/dev/null 2>&1
  assert_eq "$called" "1"
}

test_integration_report_output() {
  local report=""
  report="$(printf 'gitup=%s gitdown=%s al=%s' "ok" "ok" "ok")"
  assert_contains "$report" "gitup=ok"
  assert_contains "$report" "gitdown=ok"
  assert_contains "$report" "al=ok"
}

test_al_opens_dir_with_file_focus() {
  setup_ui_stub
  _is_interactive() { return 1; }

  # IDE 호출 인자를 캡처하는 stub
  # 새 동작: code -r DIR -g file
  local editor_flag_arg=""
  local editor_dir_arg=""
  local editor_file_arg=""
  code() {
    editor_flag_arg="${1:-}"
    editor_dir_arg="${2:-}"
    if [ "${3:-}" = "-g" ]; then
      editor_file_arg="${4:-}"
    fi
    return 0
  }
  get_active_ide() { echo "code"; }

  ssafy_al b 3001 py --no-git > /dev/null 2>&1

  # 외부터미널(VSCODE_WORKSPACE_FOLDER 미설정) → code -r ALGO_BASE_DIR -g file
  local expected_flag="-r"
  local expected_dir="$ALGO_BASE_DIR"
  local expected_file="$ALGO_BASE_DIR/boj/3001/boj_3001.py"

  [ "$editor_flag_arg" = "$expected_flag" ] || {
    echo "  expected editor flag: $expected_flag"
    echo "  actual   editor flag: $editor_flag_arg"
    return 1
  }
  [ "$editor_dir_arg" = "$expected_dir" ] || {
    echo "  expected editor dir: $expected_dir"
    echo "  actual   editor dir: $editor_dir_arg"
    return 1
  }
  [ "$editor_file_arg" = "$expected_file" ] || {
    echo "  expected editor file: $expected_file"
    echo "  actual   editor file: $editor_file_arg"
    return 1
  }
}

run_test "al: 비대화형 py 생성 플로우" test_al_non_interactive_py_flow
run_test "al: 대화형 back 포함 플로우" test_al_interactive_with_back_and_confirm
run_test "al: 프로젝트 교체 후 파일 포커싱 (code -r DIR -g file)" test_al_opens_dir_with_file_focus
run_test "gitup: URL 대화형 clone 플로우" test_gitup_interactive_url_clone_flow
run_test "gitup: Step4 back 후 재확인 플로우" test_gitup_step4_back_then_success
run_test "gitup: SmartLink 토큰 반영 + batch 호출" test_gitup_smartlink_applies_token_and_calls_batch
run_test "gitdown: 대화형 commit/push 플로우" test_gitdown_interactive_commit_flow
run_test "gitdown: --all 배치 플로우" test_gitdown_all_mode_flow
run_test "통합 리포트 문자열 검증" test_integration_report_output

echo ""
echo "========================================"
echo "Integration Tests Summary"
echo "passed=$pass_count failed=$fail_count total=$((pass_count + fail_count))"
echo "========================================"

if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
