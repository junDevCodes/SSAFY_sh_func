#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT_DIR/lib/update.sh"

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

test_stable_release_fallback_to_main() {
  local ref=""
  _ssafy_fetch_latest_release_tag() { return 1; }
  ref="$(_ssafy_resolve_snapshot_ref stable)"
  [ "$ref" = "main" ]
}

test_tarball_url_format_for_main() {
  local url=""
  url="$(_ssafy_build_tarball_url main)"
  [[ "$url" == *"/archive/refs/heads/main.tar.gz" ]]
}

test_algo_update_prints_applied_meta() {
  local temp_root=""
  local output=""

  temp_root="$(mktemp -d)"

  mkdir -p "$temp_root"
  printf '%s\n' "V8.1.7" > "$temp_root/VERSION"
  cat > "$temp_root/.install_meta" <<'EOF'
mode=snapshot
channel=stable
ref=main
version=V8.1.7
installed_at=2026-02-24T00:00:00+0000
EOF

  export ALGO_ROOT_DIR="$temp_root"
  _is_interactive() { return 1; }
  _ssafy_update_snapshot_install() { return 0; }
  _ssafy_update_git_install() { return 0; }
  _ssafy_migrate_legacy_git_install() { return 0; }

  output="$(ssafy_algo_update 2>&1 || true)"

  echo "$output" | grep -q "install_path=$temp_root"
  echo "$output" | grep -q "applied_version=V8.1.7"
  echo "$output" | grep -q "applied_mode=snapshot"
  echo "$output" | grep -q "applied_channel=stable"
  echo "$output" | grep -q "applied_ref=main"

  rm -rf "$temp_root"
}

run_test "stable release fallback to main" test_stable_release_fallback_to_main
run_test "tarball url format for main" test_tarball_url_format_for_main
run_test "algo-update prints applied meta" test_algo_update_prints_applied_meta

echo ""
echo "Tests: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
