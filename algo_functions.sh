#!/bin/bash

# 이전 세션에 남아있는 함수/별칭을 정리하고 최신 코드를 우선 로드한다.
{ unalias -- al gitup gitdown algo-config algo-update algo-doctor algo-help 2>/dev/null || true; }
{ unset -f -- al gitup gitdown algo_config algo-update algo-doctor algo-help ssafy_al ssafy_gitup ssafy_gitdown ssafy_algo_config ssafy_algo_update ssafy_algo_doctor ssafy_algo_help get_active_ide check_ide _confirm_commit_message _create_algo_file _handle_git_commit _open_in_editor _open_repo_file _gitup_ssafy _ssafy_next_repo init_algo_config _is_interactive _set_config_value _ensure_ssafy_config _find_ssafy_session_root _print_file_menu _choose_file_from_list _create_safe_alias 2>/dev/null || true; }

# =============================================================================
# 알고리즘 도구 함수 모음 (공개 API)
# =============================================================================

# =============================================================================
# [인코딩 방어] Windows Git Bash 환경에서 UTF-8 출력 보장
# 이미 설정된 경우 덮어쓰지 않는다.
# =============================================================================
export PYTHONUTF8=1
export PYTHONIOENCODING=UTF-8
if [ -z "${LANG:-}" ]; then
    export LANG=ko_KR.UTF-8
fi

# =============================================================================
# [V8.1 Modular Architecture]
# =============================================================================
# 스크립트 위치 감지
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ALGO_ROOT_DIR="$SCRIPT_DIR"

# VERSION 파일에서 버전 로드 (누락/읽기 실패 시 기본값 사용)
ALGO_FUNCTIONS_VERSION_DEFAULT="V8.1.7"
VERSION_FILE="$SCRIPT_DIR/VERSION"

if [ -f "$VERSION_FILE" ]; then
    read -r ALGO_FUNCTIONS_VERSION < "$VERSION_FILE" || true
    ALGO_FUNCTIONS_VERSION="${ALGO_FUNCTIONS_VERSION//$'\r'/}"
    ALGO_FUNCTIONS_VERSION="${ALGO_FUNCTIONS_VERSION//[[:space:]]/}"
fi

if [ -z "${ALGO_FUNCTIONS_VERSION:-}" ]; then
    ALGO_FUNCTIONS_VERSION="$ALGO_FUNCTIONS_VERSION_DEFAULT"
fi

# 모듈 로드
if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    source "$SCRIPT_DIR/lib/config.sh"
    source "$SCRIPT_DIR/lib/utils.sh"
    source "$SCRIPT_DIR/lib/python_env.sh"
    source "$SCRIPT_DIR/lib/auth.sh"
    source "$SCRIPT_DIR/lib/ui.sh"
    source "$SCRIPT_DIR/lib/input.sh"
    source "$SCRIPT_DIR/lib/git.sh"
    source "$SCRIPT_DIR/lib/ide.sh"
    source "$SCRIPT_DIR/lib/doctor.sh"
    source "$SCRIPT_DIR/lib/templates.sh"
    source "$SCRIPT_DIR/lib/update.sh"
    source "$SCRIPT_DIR/lib/help.sh"
else
    echo "[ERROR] 필수 모듈을 찾을 수 없습니다: $SCRIPT_DIR/lib/" >&2
    return 1
fi

# [V7.6] 설정 헬퍼/별칭
algo_config() { ssafy_algo_config "$@"; }
alias algo-config='ssafy_algo_config'

# 모듈 구성 안내
# - lib/config.sh    : 설정 관리
# - lib/utils.sh     : 공통 유틸리티
# - lib/auth.sh      : 인증/토큰 관리
# - lib/git.sh       : Git 작업
# - lib/ide.sh       : IDE 탐색/열기
# - lib/templates.sh : 템플릿 생성
# - lib/doctor.sh    : 시스템 진단
# - lib/update.sh    : 업데이트 확인/실행

init_algo_config
_setup_ide_aliases

if [ -o monitor ]; then
    # 백그라운드 업데이트 체크 시 job-control 노이즈를 억제한다.
    set +m
    _check_update
    set -m
else
    _check_update
fi

if type ui_panel_begin > /dev/null 2>&1; then
    ui_panel_begin "SSAFY Algo Tools" "Version ${ALGO_FUNCTIONS_VERSION}"
    ui_info "Loaded from: ${ALGO_ROOT_DIR}"
    ui_ok "알고리즘 셸 함수 로드 완료!"
    ui_info "도움말: algo-help | 설정: algo-config edit"
    ui_panel_end
else
    echo "알고리즘 셸 함수 로드 완료! (${ALGO_FUNCTIONS_VERSION})"
    echo "Loaded from: ${ALGO_ROOT_DIR}"
    echo "도움말: algo-help"
fi

if [ -f "$(pwd)/algo_functions.sh" ] && [ "$(pwd)" != "${ALGO_ROOT_DIR}" ]; then
    if type ui_warn >/dev/null 2>&1; then
        ui_warn "현재 리포와 로드된 경로가 다릅니다. source ./algo_functions.sh 를 실행하세요."
    else
        echo "[WARN] Current repo differs from loaded path. Run: source ./algo_functions.sh"
    fi
fi

# 업데이트 알림 (배경 체크 결과, 파일로 전달됨)
_ALGO_NOTIF_FILE="${ALGO_UPDATE_NOTIFICATION_FILE:-$HOME/.algo_update_notification}"
if [ -f "$_ALGO_NOTIF_FILE" ]; then
    _upd_cur=$(sed -n '1p' "$_ALGO_NOTIF_FILE" 2>/dev/null || true)
    _upd_new=$(sed -n '2p' "$_ALGO_NOTIF_FILE" 2>/dev/null || true)
    if [ -n "$_upd_cur" ] && [ -n "$_upd_new" ]; then
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "🆕 업데이트 가능: $_upd_cur → $_upd_new  |  'algo-update' 실행하세요."
        else
            echo "  ⚠ [WARN] 업데이트 가능: $_upd_cur → $_upd_new  |  실행: algo-update"
        fi
    fi
    unset _upd_cur _upd_new
fi
unset _ALGO_NOTIF_FILE

# 안전한 별칭 생성
_create_safe_alias() {
    local alias_name="$1"
    local target_func="$2"

    if ! type "$alias_name" &>/dev/null; then
        alias "$alias_name"="$target_func"
    else
        # 이미 SSAFY 도구로 등록된 별칭/함수는 재바인딩을 허용한다.
        local type_out
        type_out=$(type "$alias_name" 2>/dev/null)
        if [[ "$type_out" == *"ssafy_"* ]] || [[ "$type_out" == *"function"* ]]; then
            alias "$alias_name"="$target_func"
        else
            echo "주의: '$alias_name' 명령이 이미 존재하여 덮어쓰지 않습니다."
            echo "    -> '$target_func' 명령을 직접 사용하세요."
        fi
    fi
}

_create_safe_alias "al" "ssafy_al"
_create_safe_alias "gitup" "ssafy_gitup"
_create_safe_alias "gitdown" "ssafy_gitdown"
alias algo-update="ssafy_algo_update"
alias algo-doctor="ssafy_algo_doctor"
alias algo-help="ssafy_algo_help"