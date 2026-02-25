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

test_snapshot_update_force_bypasses_uptodate_guard() (
  local temp_root=""
  local stage_seed=""
  local output=""
  local swap_called=0

  temp_root="$(mktemp -d)"
  stage_seed="$(mktemp -d)"

  mkdir -p "$temp_root/lib" "$stage_seed/lib"
  printf '%s\n' "V8.1.7" > "$temp_root/VERSION"
  printf '%s\n' "V8.1.7" > "$stage_seed/VERSION"
  : > "$stage_seed/algo_functions.sh"
  : > "$stage_seed/lib/update.sh"

  cat > "$temp_root/.install_meta" <<'EOF'
mode=snapshot
channel=stable
ref=main
version=V8.1.7
installed_at=2026-02-24T00:00:00+0000
EOF

  cat > "$stage_seed/.install_meta" <<'EOF'
mode=snapshot
channel=stable
ref=main
version=V8.1.7
installed_at=2026-02-25T00:00:00+0000
EOF

  _ssafy_extract_snapshot_to_dir() {
    cp -R "$stage_seed"/. "$1"/
  }
  _ssafy_swap_with_backup() {
    swap_called=$((swap_called + 1))
    rm -rf "$2"
    return 0
  }

  output="$(_ssafy_update_snapshot_install "$temp_root" stable true 2>&1)"
  echo "$output" | grep -q "Snapshot update completed"
  [ "$swap_called" -eq 1 ]

  rm -rf "$temp_root" "$stage_seed"
)

test_swap_backup_keeps_latest_only_on_success() (
  local temp_root=""
  local script_dir=""
  local staged_dir=""
  local old_backup_a=""
  local old_backup_b=""
  local -a backups=()

  temp_root="$(mktemp -d)"
  script_dir="$temp_root/ssafy_tools"
  staged_dir="$temp_root/staged_new"
  old_backup_a="$temp_root/ssafy_tools.backup.20240101010101"
  old_backup_b="$temp_root/ssafy_tools.backup.20240202020202"

  mkdir -p "$script_dir" "$staged_dir" "$old_backup_a" "$old_backup_b"
  printf '%s\n' "old" > "$script_dir/marker.txt"
  printf '%s\n' "new" > "$staged_dir/marker.txt"

  _ssafy_swap_with_backup "$script_dir" "$staged_dir" >/dev/null

  [ -f "$script_dir/marker.txt" ]
  grep -q "^new$" "$script_dir/marker.txt"
  while IFS= read -r line; do
    backups+=("$line")
  done < <(find "$temp_root" -maxdepth 1 -type d -name 'ssafy_tools.backup.*' | sort)
  [ "${#backups[@]}" -eq 1 ]
  [ ! -d "$old_backup_a" ]
  [ ! -d "$old_backup_b" ]
  [ -f "${backups[0]}/marker.txt" ]
  grep -q "^old$" "${backups[0]}/marker.txt"

  rm -rf "$temp_root"
)

test_swap_backup_preserves_old_on_failure() (
  local temp_root=""
  local script_dir=""
  local old_backup=""
  local staged_dir=""

  temp_root="$(mktemp -d)"
  script_dir="$temp_root/ssafy_tools"
  old_backup="$temp_root/ssafy_tools.backup.20240101010101"
  staged_dir="$temp_root/staged_missing"

  mkdir -p "$script_dir" "$old_backup"
  printf '%s\n' "current" > "$script_dir/marker.txt"
  printf '%s\n' "legacy" > "$old_backup/legacy.txt"

  if _ssafy_swap_with_backup "$script_dir" "$staged_dir" >/dev/null 2>&1; then
    rm -rf "$temp_root"
    return 1
  fi

  [ -f "$script_dir/marker.txt" ]
  grep -q "^current$" "$script_dir/marker.txt"
  [ -d "$old_backup" ]
  [ -f "$old_backup/legacy.txt" ]

  rm -rf "$temp_root"
)

run_test "stable release fallback to main" test_stable_release_fallback_to_main
run_test "tarball url format for main" test_tarball_url_format_for_main
run_test "algo-update prints applied meta" test_algo_update_prints_applied_meta
run_test "force 옵션은 동일 버전에서도 swap을 실행해야 한다" test_snapshot_update_force_bypasses_uptodate_guard
run_test "swap 성공 시 최신 백업 1개만 유지해야 한다" test_swap_backup_keeps_latest_only_on_success
run_test "swap 실패 시 기존 백업을 보존해야 한다" test_swap_backup_preserves_old_on_failure

echo ""
echo "Tests: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
