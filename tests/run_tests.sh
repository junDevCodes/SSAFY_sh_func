#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR: line $LINENO: $BASH_COMMAND" >&2' ERR

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/algo_functions.sh"

if command -v mktemp >/dev/null 2>&1; then
  TEST_ROOT="$(mktemp -d)"
else
  TEST_ROOT="$ROOT_DIR/.tmp_test_$$"
  mkdir -p "$TEST_ROOT"
fi
cleanup() {
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
IDE_PRIORITY="code"
SSAFY_BASE_URL="https://lab.ssafy.com"
SSAFY_USER_ID="testuser"
EOF

# shellcheck source=/dev/null
source "$SCRIPT_PATH"

mkdir -p "$ALGO_BASE_DIR"

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

assert_file_exists() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "  expected file: $path"
    return 1
  fi
}

assert_file_not_exists() {
  local path="$1"
  if [ -f "$path" ]; then
    echo "  unexpected file: $path"
    return 1
  fi
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

test_cpp_only_creates_cpp() {
  al b 1012 cpp --no-git --no-open
  local dir="$ALGO_BASE_DIR/boj/1012"
  assert_file_exists "$dir/boj_1012.cpp"
  assert_file_not_exists "$dir/boj_1012.py"
  assert_file_exists "$dir/sample_input.txt"
}

test_py_default_creates_py() {
  al b 1013 --no-git --no-open
  local dir="$ALGO_BASE_DIR/boj/1013"
  assert_file_exists "$dir/boj_1013.py"
  assert_file_not_exists "$dir/boj_1013.cpp"
  assert_file_exists "$dir/sample_input.txt"
}

test_cpp_no_lang_when_cpp_exists() {
  al b 1014 cpp --no-git --no-open
  al b 1014 --no-git --no-open
  local dir="$ALGO_BASE_DIR/boj/1014"
  assert_file_exists "$dir/boj_1014.cpp"
  assert_file_not_exists "$dir/boj_1014.py"
}

test_cpp_with_msg_flag() {
  al b 1015 cpp --msg "feat: test" --no-git --no-open
  local dir="$ALGO_BASE_DIR/boj/1015"
  assert_file_exists "$dir/boj_1015.cpp"
  assert_file_not_exists "$dir/boj_1015.py"
}

run_test "cpp only creates cpp" test_cpp_only_creates_cpp
run_test "py default creates py" test_py_default_creates_py
run_test "cpp exists without lang keeps cpp only" test_cpp_no_lang_when_cpp_exists
run_test "cpp with msg flag creates cpp" test_cpp_with_msg_flag

echo ""
echo "Tests: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
