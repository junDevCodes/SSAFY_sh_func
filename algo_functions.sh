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
ALGO_FUNCTIONS_VERSION="V8.1.0"

# 스크립트 위치 감지 (Module Loading용)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load Modules
if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    source "$SCRIPT_DIR/lib/config.sh"
    source "$SCRIPT_DIR/lib/utils.sh"
    source "$SCRIPT_DIR/lib/python_env.sh"
    source "$SCRIPT_DIR/lib/auth.sh"
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

# 파일 생성 내부 함수

# =============================================================================
# Helper: _find_ssafy_session_root
# 현재 위치에서 상위로 이동하며 세션 루트(.ssafy_session_meta 또는 .ssafy_playlist가 있는 곳)를 찾음
# =============================================================================

# 커밋 메시지 확인/수정

# Git 커밋 처리 내부 함수

# 에디터에서 파일 열기 내부 함수

# =============================================================================
# _gitdown_all - 전체 실습실 일괄 Push
# _sync_playlist_status - Git 로그 기반 완료 여부 동기화 (Auto-Sync)
# =============================================================================

# =============================================================================
# _show_submission_links - 제출 링크 출력
# =============================================================================

# =============================================================================
# gitup - Git 저장소 클론 및 시작
# =============================================================================


# ===================================================
# get_ide - 설정된 IDE 반환
# ===================================================

init_algo_config
_check_update

echo "✅ 알고리즘 셸 함수 로드 완료! (${ALGO_FUNCTIONS_VERSION})"
echo "💡 'algo-config edit'로 설정을 변경할 수 있습니다"

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
