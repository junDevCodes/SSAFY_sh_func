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
  # [Windows Fix] 현재 디렉토리가 삭제 대상 내부에 있으면 삭제 실패함
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
  ssafy_al b 1012 cpp --no-git --no-open
  local dir="$ALGO_BASE_DIR/boj/1012"
  assert_file_exists "$dir/boj_1012.cpp"
  assert_file_not_exists "$dir/boj_1012.py"
  assert_file_exists "$dir/sample_input.txt"
}

test_py_default_creates_py() {
  ssafy_al b 1013 --no-git --no-open
  local dir="$ALGO_BASE_DIR/boj/1013"
  assert_file_exists "$dir/boj_1013.py"
  assert_file_not_exists "$dir/boj_1013.cpp"
  assert_file_exists "$dir/sample_input.txt"
}

test_cpp_no_lang_when_cpp_exists() {
  ssafy_al b 1014 cpp --no-git --no-open
  ssafy_al b 1014 --no-git --no-open
  local dir="$ALGO_BASE_DIR/boj/1014"
  assert_file_exists "$dir/boj_1014.cpp"
  assert_file_not_exists "$dir/boj_1014.py"
}

test_cpp_with_msg_flag() {
  ssafy_al b 1015 cpp --msg "feat: test" --no-git --no-open
  local dir="$ALGO_BASE_DIR/boj/1015"
  assert_file_exists "$dir/boj_1015.cpp"
  assert_file_not_exists "$dir/boj_1015.py"
}

# Git 커밋 테스트를 위한 임시 Git 저장소 설정
setup_git_repo() {
  cd "$ALGO_BASE_DIR" || return 1
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
}

# 테스트: 파일 변경 후 al 실행 시 커밋 발생
test_commit_when_file_changed() {
  local dir="$ALGO_BASE_DIR/boj/1016"
  
  # 1. cpp 파일 생성
  ssafy_al b 1016 cpp --no-git --no-open
  assert_file_exists "$dir/boj_1016.cpp"
  
  # 2. Git 저장소 초기화 및 첫 커밋
  setup_git_repo
  git add .
  git commit -q -m "initial"
  
  # 3. 파일 수정 (문제 풀이 시뮬레이션)
  echo "// solution" >> "$dir/boj_1016.cpp"
  
  # 4. al 실행 (--no-open만, git은 활성화)
  ssafy_al b 1016 --no-open
  
  # 5. 커밋이 발생했는지 확인 (최신 커밋 메시지에 "solve" 포함)
  local last_commit
  last_commit=$(git log -1 --pretty=%B 2>/dev/null || echo "")
  if [[ "$last_commit" != *"solve"* ]]; then
    echo "  expected commit with 'solve' prefix, got: $last_commit"
    return 1
  fi
}

# 테스트: cpp 존재 시 명시적 py 지정으로 py 파일 생성
test_explicit_py_creates_py_when_cpp_exists() {
  local dir="$ALGO_BASE_DIR/boj/1017"
  
  # 1. cpp 파일 먼저 생성
  ssafy_al b 1017 cpp --no-git --no-open
  assert_file_exists "$dir/boj_1017.cpp"
  assert_file_not_exists "$dir/boj_1017.py"
  
  # 2. 명시적으로 py 지정하여 실행
  ssafy_al b 1017 py --no-git --no-open
  
  # 3. 이제 둘 다 존재해야 함
  assert_file_exists "$dir/boj_1017.cpp"
  assert_file_exists "$dir/boj_1017.py"
}

run_test "cpp only creates cpp" test_cpp_only_creates_cpp
run_test "py default creates py" test_py_default_creates_py
run_test "cpp exists without lang keeps cpp only" test_cpp_no_lang_when_cpp_exists
run_test "cpp with msg flag creates cpp" test_cpp_with_msg_flag
run_test "commit when file changed" test_commit_when_file_changed
run_test "explicit py creates py when cpp exists" test_explicit_py_creates_py_when_cpp_exists

run_external_test() {
  local name="$1"
  local script="$2"
  if bash "$ROOT_DIR/$script"; then
    pass "$name"
  else
    fail "$name"
  fi
}

run_external_test "gitup flow unit suite" "tests/test_gitup_flow.sh"
run_external_test "algo-help unit suite" "tests/test_algo_help.sh"
run_external_test "ui panel batch suite" "tests/test_ui_panel_batch.sh"
run_external_test "commands integration suite" "tests/test_commands_integration.sh"
run_external_test "update flow suite" "tests/test_update_flow.sh"
run_external_test "install post-setup suite" "tests/test_install_post_setup.sh"
run_external_test "encoding smoke suite" "tests/test_encoding_smoke.sh"
run_external_test "input confirm scope suite" "tests/test_input_confirm_scope.sh"

# wizard first_run_setup 단위 테스트 (Python)
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_CMD="python"
else
  PYTHON_CMD=""
fi

if [ -n "$PYTHON_CMD" ]; then
  if "$PYTHON_CMD" "$ROOT_DIR/tests/test_wizard_first_run.py"; then
    pass "wizard first_run_setup suite"
  else
    fail "wizard first_run_setup suite"
  fi
else
  echo "SKIP: wizard first_run_setup suite (python not found)"
fi

echo ""
echo "Tests: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
