#!/bin/bash

# 이전에 정의된 함수/별칭이 남아 있을 때 새 버전을 확실히 적용하기 위해 초기화
{ unalias -- al gitup gitdown algo-config algo-update algo-doctor 2>/dev/null || true; }
{ unset -f -- al gitup gitdown algo_config algo-update algo-doctor ssafy_al ssafy_gitup ssafy_gitdown ssafy_algo_config ssafy_algo_update ssafy_algo_doctor get_active_ide check_ide _confirm_commit_message _create_algo_file _handle_git_commit _open_in_editor _open_repo_file _gitup_ssafy _ssafy_next_repo init_algo_config _is_interactive _set_config_value _ensure_ssafy_config _find_ssafy_session_root _print_file_menu _choose_file_from_list _create_safe_alias 2>/dev/null || true; }


# =============================================================================
# 알고리즘 문제 풀이 자동화 셸 함수 (공개용)
# =============================================================================

# =============================================================================
# [V8.1 Modular Architecture]
# =============================================================================
# 스크립트 위치 감지 (Module Loading용)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Phase 1 Task 1-2: ALGO_ROOT_DIR 전역 변수 도입
export ALGO_ROOT_DIR="$SCRIPT_DIR"

# =============================================================================
# 버전 로드 (SSOT: VERSION 파일)
# - VERSION 파일이 없거나 읽기 실패 시 기본값으로 폴백
# - Windows(Git Bash) CRLF(\r) 제거 및 공백 제거 처리
# =============================================================================
ALGO_FUNCTIONS_VERSION_DEFAULT="V8.1.5"
VERSION_FILE="$SCRIPT_DIR/VERSION"

if [ -f "$VERSION_FILE" ]; then
    read -r ALGO_FUNCTIONS_VERSION < "$VERSION_FILE" || true
    ALGO_FUNCTIONS_VERSION="${ALGO_FUNCTIONS_VERSION//$'\r'/}"
    ALGO_FUNCTIONS_VERSION="${ALGO_FUNCTIONS_VERSION//[[:space:]]/}"
fi

if [ -z "${ALGO_FUNCTIONS_VERSION:-}" ]; then
    ALGO_FUNCTIONS_VERSION="$ALGO_FUNCTIONS_VERSION_DEFAULT"
fi

# Load Modules
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
else
    # Fallback: 설치 경로가 아닌 경우 (개발 중 등)
    # 하지만 보통은 같이 다님. 에러 처리만.
    echo "❌ 필수 모듈을 찾을 수 없습니다: $SCRIPT_DIR/lib/" >&2
    return 1
fi

# 업데이트 명령어 (V7.6 네임스페이스)



# 설정 편집 명령어 (V7.6 네임스페이스)
# [V7.6] 별칭 등록 (algo_config 사용처 호환성)
algo_config() { ssafy_algo_config "$@"; }
alias algo-config='ssafy_algo_config'

# =============================================================================
# al - 알고리즘 문제 환경 설정 (V7.6 네임스페이스)
# =============================================================================

# =============================================================================
# 모듈 구조 안내 (V8.1 Modular Architecture)
# =============================================================================
# 다음 함수들은 각 모듈로 분리되어 있습니다:
#   - lib/config.sh    : 설정 관리 (init_algo_config, ssafy_algo_config)
#   - lib/utils.sh     : 공통 유틸리티 (_is_interactive, _check_service_status)
#   - lib/auth.sh      : 인증/토큰 관리 (_ensure_token, _is_token_expired)
#   - lib/git.sh       : Git 작업 (ssafy_gitup, ssafy_gitdown, _open_repo_file)
#   - lib/ide.sh       : IDE 탐색/열기 (get_ide, get_active_ide, _open_in_editor)
#   - lib/templates.sh : 알고리즘 템플릿 생성 (ssafy_al, _create_algo_file)
#   - lib/doctor.sh    : 시스템 진단 (ssafy_algo_doctor)
#   - lib/update.sh    : 자동 업데이트 (ssafy_algo_update, _check_update)
# =============================================================================

init_algo_config
# Phase 2 Task 2-3: _setup_ide_aliases 호출 추가
_setup_ide_aliases
_check_update

if type ui_ok >/dev/null 2>&1; then
    ui_ok "Algo shell functions loaded (${ALGO_FUNCTIONS_VERSION})"
    ui_hint "Run 'algo-config edit' to update settings."
else
    echo "Algo shell functions loaded (${ALGO_FUNCTIONS_VERSION})"
    echo "Run 'algo-config edit' to update settings."
fi

# =============================================================================
# algo-doctor - 시스템 및 설정 진단 도구 (V7.0) (V7.6 네임스페이스)
# =============================================================================


# =============================================================================
# 안전한 별칭 생성 (V7.6 네임스페이스)
# =============================================================================
_create_safe_alias() {
    local alias_name="$1"
    local target_func="$2"
    
    # 기존 명령어/함수/별칭 존재 여부 확인
    if ! type "$alias_name" &>/dev/null; then
        alias "$alias_name"="$target_func"
    else
        # 이미 SSAFY 도구로 정의된 경우 재정의 허용 (기존 alias, function 포함)
        # type 출력 예: "al is a function", "al is aliased to `ssafy_al'"
        local type_out=$(type "$alias_name" 2>/dev/null)
        if [[ "$type_out" == *"ssafy_"* ]] || [[ "$type_out" == *"function"* ]]; then
            alias "$alias_name"="$target_func"
        else
            echo "⚠️  '$alias_name' 명령어/별칭이 이미 존재하여 덮어쓰지 않았습니다."
            echo "    -> '$target_func' 명령어를 직접 사용하세요."
        fi
    fi
}

# 별칭 등록 (V7.6)
_create_safe_alias "al" "ssafy_al"
_create_safe_alias "gitup" "ssafy_gitup"
_create_safe_alias "gitdown" "ssafy_gitdown"
# algo-config는 위에서 이미 처리됨
alias algo-update="ssafy_algo_update"
alias algo-doctor="ssafy_algo_doctor"
