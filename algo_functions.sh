#!/bin/bash

# 이전에 정의된 함수/별칭이 남아 있을 때 새 버전을 확실히 적용하기 위해 초기화
unalias -- al gitup gitdown algo-config 2>/dev/null
unset -f -- al gitup gitdown algo_config get_active_ide check_ide _confirm_commit_message _create_algo_file _handle_git_commit _open_in_editor _open_repo_file _gitup_ssafy _ssafy_next_repo init_algo_config _is_interactive _set_config_value _ensure_ssafy_config _find_ssafy_session_root _print_file_menu _choose_file_from_list 2>/dev/null

# =============================================================================
# 알고리즘 문제 풀이 자동화 셸 함수 (공개용)
# =============================================================================

# 설정 파일 경로
ALGO_CONFIG_FILE="$HOME/.algo_config"
ALGO_FUNCTIONS_VERSION="V6"
ALGO_UPDATE_CHECK_FILE="$HOME/.algo_update_last_check"

_check_update() {
    # .git 디렉토리가 없으면 패스 (git clone으로 설치하지 않은 경우)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ ! -d "$script_dir/.git" ]; then
        return 0
    fi

    # 하루에 한 번만 체크
    if [ -f "$ALGO_UPDATE_CHECK_FILE" ]; then
        local last_check
        last_check=$(cat "$ALGO_UPDATE_CHECK_FILE")
        local current_time
        current_time=$(date +%s)
        local diff=$((current_time - last_check))
        
        # 86400초 = 24시간
        if [ $diff -lt 86400 ]; then
            return 0
        fi
    fi

    # 백그라운드에서 체크하지 않고, 타임아웃을 짧게 주어 확인
    # (사용자 경험을 해치지 않기 위해 1초 내에 응답 없으면 넘어감)
    if command -v git > /dev/null 2>&1; then
        (
            cd "$script_dir" || exit
            # 원격 정보 갱신 (1초 타임아웃)
            if timeout 1s git fetch origin main > /dev/null 2>&1; then
                local local_hash
                local remote_hash
                local_hash=$(git rev-parse HEAD)
                remote_hash=$(git rev-parse origin/main)
                
                if [ "$local_hash" != "$remote_hash" ]; then
                    echo ""
                    echo "📦 [Update info] 새로운 버전이 감지되었습니다!"
                    echo "   현재: $ALGO_FUNCTIONS_VERSION -> 최신 버전으로 업데이트 가능"
                    echo "   👉 'algo-update'를 입력하여 업데이트하세요."
                    echo ""
                fi
                # 체크 시간 갱신
                date +%s > "$ALGO_UPDATE_CHECK_FILE"
            fi
        ) & # 백그라운드 실행으로 셸 로딩 지연 방지
    fi
}

algo-update() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    echo "🔄 최신 버전으로 업데이트 중..."
    (
        cd "$script_dir" || exit 1
        if git pull origin main; then
            echo "✅ 업데이트 완료! 변경 사항을 적용하려면 터미널을 다시 시작하거나 아래 명령어를 실행하세요:"
            echo "   source $ALGO_CONFIG_FILE"
        else
            echo "❌ 업데이트 실패. 직접 git pull을 시도해보세요."
        fi
    )
}

_is_interactive() {
    [ -t 0 ] && [ -t 1 ]
}

_set_config_value() {
    local key="$1"
    local value="$2"
    local file="$ALGO_CONFIG_FILE"

    if [ -z "$key" ] || [ ! -f "$file" ]; then
        return 1
    fi

    local escaped="$value"
    escaped="${escaped//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"

    local tmp="${file}.tmp.$$"
    awk -v key="$key" -v val="$escaped" '
        BEGIN { found = 0 }
        $0 ~ ("^" key "=") {
            print key "=\"" val "\""
            found = 1
            next
        }
        { print }
        END {
            if (found == 0) {
                print key "=\"" val "\""
            }
        }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

_ensure_ssafy_config() {
    if [ -z "${SSAFY_BASE_URL:-}" ]; then
        if _is_interactive; then
            local input=""
            read -r -p "SSAFY GitLab base URL [https://lab.ssafy.com]: " input
            SSAFY_BASE_URL="${input:-https://lab.ssafy.com}"
            _set_config_value "SSAFY_BASE_URL" "$SSAFY_BASE_URL" >/dev/null 2>&1 || true
        else
            SSAFY_BASE_URL="https://lab.ssafy.com"
        fi
    fi

    if [ -z "${SSAFY_USER_ID:-}" ]; then
        if _is_interactive; then
            local input=""
            read -r -p "SSAFY namespace/user id (e.g. jylee1702 or group/user): " input
            if [ -n "${input//[[:space:]]/}" ]; then
                SSAFY_USER_ID="$input"
                _set_config_value "SSAFY_USER_ID" "$SSAFY_USER_ID" >/dev/null 2>&1 || true
            fi
        fi
    fi

    if [ -z "${SSAFY_AUTH_TOKEN:-}" ] || [[ "$SSAFY_AUTH_TOKEN" == "Bearer your_token_here" ]]; then
        if _is_interactive; then
            local input=""
            # 자동으로 묻지 않음 (실행 시점에 물어보도록 스킵하거나, init 때는 빈값 허용)
            # 여기서는 파일에 값이 없으면 초기화만
            :
        fi
    fi
}

_find_ssafy_session_root() {
    local start_dir="${1:-$(pwd)}"
    local dir="$start_dir"

    while true; do
        if [ -f "$dir/.ssafy_session_root" ]; then
            echo "$dir"
            return 0
        fi
        if [ -z "$dir" ] || [ "$dir" = "/" ] || [ "$dir" = "$HOME" ] || [ "$dir" = "." ]; then
            break
        fi
        dir="$(dirname "$dir")"
    done

    return 1
}

# 기본 설정 초기화
init_algo_config() {
    if [ ! -f "$ALGO_CONFIG_FILE" ]; then
        cat > "$ALGO_CONFIG_FILE" << 'EOF'
# 알고리즘 문제 풀이 디렉토리 설정
ALGO_BASE_DIR="$HOME/algorithm"

# Git 설정
GIT_DEFAULT_BRANCH="main"
GIT_COMMIT_PREFIX="solve"
GIT_AUTO_PUSH=true

# IDE 우선순위 (공백으로 구분)
IDE_PRIORITY="code pycharm idea subl"

# SSAFY 설정 (처음 실행 시 입력받아 저장합니다)
SSAFY_BASE_URL=""
SSAFY_USER_ID=""
SSAFY_AUTH_TOKEN="Bearer your_token_here"
EOF
        echo "✅ 설정 파일 생성: $ALGO_CONFIG_FILE"
        echo "💡 'algo-config' 명령어로 설정을 변경할 수 있습니다"
    fi
    source "$ALGO_CONFIG_FILE"
    
    # Python 스크립트를 위해 토큰 자동 export
    if [ -n "$SSAFY_AUTH_TOKEN" ] && [[ "$SSAFY_AUTH_TOKEN" != "Bearer your_token_here" ]]; then
        export SSAFY_AUTH_TOKEN
    fi
    
    _ensure_ssafy_config
}

# 설정 편집 명령어
algo_config() {
    init_algo_config
    
    if [ "$1" = "edit" ]; then
        ${EDITOR:-nano} "$ALGO_CONFIG_FILE"
        echo "✅ 설정 파일을 편집했습니다. 'source ~/.bashrc'로 적용하세요"
        return
    fi
    
    if [ "$1" = "show" ]; then
        echo "📋 현재 설정:"
        cat "$ALGO_CONFIG_FILE"
        return
    fi
    
    if [ "$1" = "reset" ]; then
        rm -f "$ALGO_CONFIG_FILE"
        init_algo_config
        echo "✅ 설정이 초기화되었습니다"
        return
    fi
    
    echo "사용법:"
    echo "  algo-config edit   - 설정 파일 편집"
    echo "  algo-config show   - 현재 설정 보기"
    echo "  algo-config reset  - 설정 초기화"
}
alias algo-config='algo_config'

# =============================================================================
# al - 알고리즘 문제 환경 설정
# =============================================================================
al() {
    init_algo_config
    
    # 인자 검증
    if [ $# -eq 0 ]; then
        echo "❗️사용법: al <사이트> <문제번호> [py|cpp] [옵션]"
        echo ""
        echo "📋 지원 사이트:"
        echo "  s  → SWEA (Samsung SW Expert Academy)"
        echo "  b  → BOJ (Baekjoon Online Judge)"
        echo "  p  → Programmers"
        echo ""
        echo "🧩 언어:"
        echo "  py  → Python (기본값)"
        echo "  cpp → C++"
        echo ""
        echo "⚙️  옵션:"
        echo "  --no-git         Git 커밋/푸시 건너뛰기"
        echo "  --no-open        파일 열기 건너뛰기"
        echo "  --msg, -m <msg>  커밋 메시지 지정"
        echo ""
        echo "💡 사용 예제:"
        echo "  al s 1234                  # SWEA 1234번 문제"
        echo "  al b 10950                 # BOJ 10950번 문제"
        echo "  al p 42576                 # 프로그래머스 42576번 문제"
        echo "  al b 1000 --no-git         # Git 작업 없이 파일만 생성"
        echo "  al b 1000 --msg \"fix: ty\"  # 커밋 메시지 지정"
        echo "  al b 1000 cpp              # C++ 파일 생성"
        return 1
    fi
    
    local site_code="$1"
    local problem="$2"
    local lang="py"
    local lang_provided=false
    local skip_git=false
    local skip_open=false
    local custom_commit_msg=""

    # 옵션/언어 파싱
    shift 2
    while [ $# -gt 0 ]; do
        case "$1" in
            py|cpp)
                if [ "$lang_provided" = false ]; then
                    lang="$1"
                    lang_provided=true
                else
                    echo "❗ 언어는 하나만 지정할 수 있습니다."
                    return 1
                fi
                ;;
            --no-git) skip_git=true ;;
            --no-open) skip_open=true ;;
            --msg|-m)
                shift
                if [ -z "$1" ] || [[ "$1" == --* ]]; then
                    echo "❗ --msg 옵션에는 커밋 메시지가 필요합니다."
                    return 1
                fi
                custom_commit_msg="$1"
                ;;
            --msg=*)
                custom_commit_msg="${1#--msg=}"
                if [ -z "$custom_commit_msg" ]; then
                    echo "❗ --msg 옵션에는 커밋 메시지가 필요합니다."
                    return 1
                fi
                ;;
            --*)
                echo "❗ 알 수 없는 옵션: $1"
                return 1
                ;;
            *)
                if [ -z "$custom_commit_msg" ]; then
                    custom_commit_msg="$1"
                else
                    echo "❗ 커밋 메시지에 공백이 있으면 따옴표로 감싸주세요."
                    echo "   예: al b 1000 \"feat: new commit\""
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [ -n "$custom_commit_msg" ] && [ -z "${custom_commit_msg//[[:space:]]/}" ]; then
        echo "❗ 커밋 메시지가 비어 있습니다."
        return 1
    fi
    
    # 사이트 코드 검증
    local site_name file_prefix site_display
    case "$site_code" in
        s|swea)
            site_name="swea"
            file_prefix="swea"
            site_display="SWEA"
            ;;
        b|boj)
            site_name="boj"
            file_prefix="boj"
            site_display="BOJ"
            ;;
        p|programmers)
            site_name="programmers"
            file_prefix="programmers"
            site_display="Programmers"
            ;;
        *)
            echo "❗️지원하지 않는 사이트 코드: '$site_code'"
            echo "올바른 코드: s, b, p"
            return 1
            ;;
    esac
    
    # 문제번호 검증
    if ! [[ "$problem" =~ ^[0-9]+$ ]]; then
        echo "❗️문제번호는 숫자여야 합니다: '$problem'"
        return 1
    fi
    
    # 디렉토리 및 파일 경로 설정
    local dir="$ALGO_BASE_DIR/$site_name/$problem"
    local py_file="$dir/${file_prefix}_${problem}.py"
    local cpp_file="$dir/${file_prefix}_${problem}.cpp"
    local file=""
    
    echo "🎯 사이트: $site_display"
    echo "📝 문제번호: $problem"
    echo "📁 경로: $dir"
    
    # 디렉토리 생성
    mkdir -p "$dir"
    
    # 파일 생성 또는 Git 작업
    local has_py=false
    local has_cpp=false
    if [ -f "$py_file" ]; then
        has_py=true
    fi
    if [ -f "$cpp_file" ]; then
        has_cpp=true
    fi

    if [ "$lang_provided" = true ]; then
        if [ "$lang" = "cpp" ]; then
            file="$cpp_file"
        else
            file="$py_file"
        fi

        if [ ! -f "$file" ]; then
            _create_algo_file "$file" "$site_name" "$site_display" "$problem" "$lang"
        else
            echo "📄 기존 파일 발견!"
            # 변경사항이 있는지 확인
            local has_changes=false
            if [ -d "$dir/.git" ] || git -C "$dir" rev-parse --git-dir > /dev/null 2>&1; then
                local git_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
                if [ -n "$git_root" ]; then
                    local rel_dir=$(realpath --relative-to="$git_root" "$dir" 2>/dev/null || echo "$dir")
                    if git -C "$git_root" status --porcelain "$rel_dir" 2>/dev/null | grep -q .; then
                        has_changes=true
                    fi
                fi
            fi
            
            if [ "$has_changes" = true ] && [ "$skip_git" = false ]; then
                echo "✨ 변경사항 감지 → 커밋/푸시 모드"
                _handle_git_commit "$file" "$problem" "$custom_commit_msg" "$lang"
            else
                if [ "$has_changes" = false ]; then
                    echo "📝 변경사항 없음 → 파일 열기만 수행"
                else
                    echo "⏭️  Git 작업 건너뛰기"
                fi
            fi
        fi
    else
        if [ "$has_py" = false ] && [ "$has_cpp" = false ]; then
            file="$py_file"
            lang="py"
            _create_algo_file "$file" "$site_name" "$site_display" "$problem" "$lang"
        else
            # 변경사항이 있는지 확인
            local has_changes=false
            if git -C "$dir" rev-parse --git-dir > /dev/null 2>&1; then
                local git_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
                if [ -n "$git_root" ]; then
                    local rel_dir=$(realpath --relative-to="$git_root" "$dir" 2>/dev/null || echo "$dir")
                    if git -C "$git_root" status --porcelain "$rel_dir" 2>/dev/null | grep -q .; then
                        has_changes=true
                    fi
                fi
            fi
            
            if [ "$has_changes" = true ] && [ "$skip_git" = false ]; then
                echo "✨ 변경사항 감지 → 커밋/푸시 모드"
                if [ "$has_py" = true ]; then
                    _handle_git_commit "$py_file" "$problem" "$custom_commit_msg" "py"
                fi
                if [ "$has_cpp" = true ]; then
                    _handle_git_commit "$cpp_file" "$problem" "$custom_commit_msg" "cpp"
                fi
            else
                if [ "$has_changes" = false ]; then
                    echo "📝 변경사항 없음 → 파일 열기만 수행"
                else
                    echo "⏭️  Git 작업 건너뛰기"
                fi
            fi

            if [ "$has_py" = true ]; then
                file="$py_file"
                lang="py"
            else
                file="$cpp_file"
                lang="cpp"
            fi
        fi
    fi
    
    # 파일 열기
    if [ "$skip_open" = false ]; then
        local editor=$(get_active_ide)
        echo "🎉 $editor에서 파일을 여는 중..."
        _open_in_editor "$editor" "$file"
    else
        echo "⏭️  파일 열기 건너뛰기"
    fi
}

# 파일 생성 내부 함수
_create_algo_file() {
    local file="$1"
    local site_name="$2"
    local site_display="$3"
    local problem="$4"
    local lang="$5"
    
    echo "🆕 새 문제 파일 생성 중..."

    local sample_file="$(dirname "$file")/sample_input.txt"
    if [ ! -f "$sample_file" ]; then
        : > "$sample_file"
    fi

    if [ "$lang" = "cpp" ]; then
        : > "$file"
        echo "✅ 파일 생성 완료!"
        return
    fi
    
    cat > "$file" <<PYCODE
# $site_display $problem 문제 풀이
import sys
from pathlib import Path

# 로컬 테스트용 파일 입력 설정
BASE_DIR = Path(__file__).resolve().parent
sys.stdin = (BASE_DIR / 'sample_input.txt').open('r', encoding='utf-8')

"""
[문제 설명]


[조건]


[입력]


[출력]


[알고리즘]
1. 
2. 
3. 

[복잡도]
- 시간: O()
- 공간: O()
"""

PYCODE

    # 사이트별 템플릿 추가
    case "$site_name" in
        swea)
            cat >> "$file" <<'SWEA_CODE'
def solve():
    T = int(input())
    
    for test_case in range(1, T + 1):
        
        print(f"#{test_case}")
        

solve()
SWEA_CODE
            ;;
        boj)
            cat >> "$file" <<'BOJ_CODE'
N = int(sys.stdin.readline())

# 출력
# print(result)
BOJ_CODE
            ;;
        programmers)
            cat >> "$file" <<'PROG_CODE'
def solution(param):
    """
    프로그래머스 솔루션 함수
    """
    return param

# 테스트
if __name__ == "__main__":
    test_cases = [
        # (입력, 예상출력)
    ]

    for i, (inp, expected) in enumerate(test_cases):
        result = solution(inp)
        print(f"Test {i+1}: {'✅' if result == expected else '❌'}")
PROG_CODE
            ;;
    esac
    
    echo "✅ 파일 생성 완료!"
}

# 커밋 메시지 확인/수정
_confirm_commit_message() {
    local msg="$1"
    local answer=""

    CONFIRMED_COMMIT_MSG=""

    while true; do
        echo "✅ 커밋 메시지: $msg"
        read -r -p "이대로 커밋하고 push할까요? (y/n): " answer
        case "$answer" in
            y|Y)
                CONFIRMED_COMMIT_MSG="$msg"
                return 0
                ;;
            n|N)
                read -r -p "커밋 메시지 다시 입력: " msg
                if [ -z "${msg//[[:space:]]/}" ]; then
                    echo "❗ 커밋 메시지가 비어 있습니다."
                    return 1
                fi
                ;;
            *)
                echo "❗ y 또는 n을 입력하세요."
                ;;
        esac
    done
}

# Git 커밋 처리 내부 함수
_handle_git_commit() {
    local target_path="$1"
    local problem="$2"
    local custom_msg="$3"
    local lang="$4"
    
    # 원래 디렉토리 저장
    local original_dir=$(pwd)
    
    # Git 저장소 찾기
    local git_root=""
    local current_dir="$(dirname "$target_path")"
    
    while [ "$current_dir" != "/" ] && [ "$current_dir" != "$HOME" ]; do
        if [ -d "$current_dir/.git" ]; then
            git_root="$current_dir"
            break
        fi
        current_dir=$(dirname "$current_dir")
    done
    
    if [ -z "$git_root" ]; then
        echo "⚠️  Git 저장소를 찾을 수 없습니다"
        return
    fi
    
    cd "$git_root" || return
    
    local relative_path=$(realpath --relative-to="$git_root" "$target_path" 2>/dev/null || \
        python3 -c "import os.path; print(os.path.relpath('$target_path', '$git_root'))")
    
    echo "✅ Git 저장소: $git_root"
    echo "📁 대상: $relative_path"
    
    # 파일이 있는 폴더 전체를 추가 (sample_input.txt 등 포함)
    local relative_dir=$(dirname "$relative_path")
    # 디렉토리 내 모든 파일 추가 (슬래시 추가로 확실하게)
    git add "$relative_dir/"
    # 혹시 놓친 파일이 있을 경우 개별 파일도 추가
    git add "$relative_path"
    
    local commit_msg=""
    if [ -n "$custom_msg" ]; then
        _confirm_commit_message "$custom_msg" || return 1
        commit_msg="$CONFIRMED_COMMIT_MSG"
    else
        local lang_label="Python"
        if [ "$lang" = "cpp" ]; then
            lang_label="C++"
        fi
        commit_msg="${GIT_COMMIT_PREFIX}: ${problem} ${lang_label}"
    fi
    
    if git commit -m "$commit_msg" 2>/dev/null; then
        echo "✅ 커밋 완료: $commit_msg"
        
        if [ "$GIT_AUTO_PUSH" = true ]; then
            local current_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)
            
            # 먼저 설정된 브랜치로 시도
            if git push origin "$GIT_DEFAULT_BRANCH" 2>/dev/null; then
                echo "✅ 푸시 완료! (브랜치: $GIT_DEFAULT_BRANCH)"
            else
                # 설정된 브랜치로 실패하면 현재 브랜치로 시도
                if [ -n "$current_branch" ] && [ "$current_branch" != "$GIT_DEFAULT_BRANCH" ]; then
                    echo "⚠️  브랜치 '$GIT_DEFAULT_BRANCH'로 푸시 실패, 현재 브랜치 '$current_branch'로 시도 중..."
                    if git push origin "$current_branch" 2>/dev/null; then
                        echo "✅ 푸시 완료! (브랜치: $current_branch)"
                    else
                        echo "❌ 푸시 실패 (시도한 브랜치: $GIT_DEFAULT_BRANCH, $current_branch)"
                        echo "💡 'algo-config edit'로 브랜치명을 확인하거나 수동으로 푸시하세요"
                    fi
                else
                    echo "❌ 푸시 실패 (브랜치: $GIT_DEFAULT_BRANCH)"
                    echo "💡 'algo-config edit'로 브랜치명을 확인하거나 수동으로 푸시하세요"
                fi
            fi
        fi
    else
        echo "⚠️  커밋할 변경사항이 없습니다"
    fi
    
    # 원래 디렉토리로 복원
    cd "$original_dir" 2>/dev/null || true
}

# 에디터에서 파일 열기 내부 함수
_open_in_editor() {
    local editor="$1"
    local file="$2"
    
    case "$editor" in
        pycharm*|idea*)
            if command -v "$editor" > /dev/null 2>&1; then
                "$editor" "$file" &
            else
                echo "⚠️  $editor를 찾을 수 없습니다"
                code "$file" 2>/dev/null || echo "❌ 파일 열기 실패"
            fi
            ;;
        *)
            if command -v "$editor" > /dev/null 2>&1; then
                "$editor" "$file" &
            else
                echo "⚠️  $editor를 찾을 수 없습니다"
            fi
            ;;
    esac
}

# =============================================================================
# gitdown - Git 작업 완료 자동화
# =============================================================================
gitdown() {
    init_algo_config
    
    echo "🔍 현재 Git 상태:"
    git status --short
    echo ""
    
    local commit_msg=""
    local custom_msg=false
    local ssafy_mode=false
    local push_ok=false
    local current_repo=$(basename "$(pwd)" 2>/dev/null)

    # 기본적으로 SSAFY 폴더 패턴이면 자동 모드 활성화 (User Request)
    if [[ "$current_repo" =~ ^[A-Za-z0-9]+_(ws|hw|ex)(_[0-9]+(_[0-9]+)?)?$ ]]; then
        if [ "$ssafy_mode" = false ]; then
            ssafy_mode=true
            echo "✨ SSAFY 폴더 감지: 자동 모드 활성화"
        fi
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --ssafy|-s)
                ssafy_mode=true
                ;;
            --msg|-m)
                shift
                if [ -z "$1" ] || [[ "$1" == --* ]]; then
                    echo "❗ --msg 옵션에는 커밋 메시지가 필요합니다."
                    return 1
                fi
                commit_msg="$1"
                custom_msg=true
                ;;
            --msg=*)
                commit_msg="${1#--msg=}"
                if [ -z "$commit_msg" ]; then
                    echo "❗ --msg 옵션에는 커밋 메시지가 필요합니다."
                    return 1
                fi
                custom_msg=true
                ;;
            *)
                if [ -z "$commit_msg" ] && [[ "$1" != --* ]]; then
                    commit_msg="$1"
                    custom_msg=true
                else
                    echo "❗ 커밋 메시지에 공백이 있으면 따옴표로 감싸주세요."
                    echo "   예: gitdown \"feat: new commit\""
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [ "$custom_msg" = true ]; then
        if [ -z "${commit_msg//[[:space:]]/}" ]; then
            echo "❗ 커밋 메시지가 비어 있습니다."
            return 1
        fi
        _confirm_commit_message "$commit_msg" || return 1
        commit_msg="$CONFIRMED_COMMIT_MSG"
    else
        if [ -z "$current_repo" ] || [ "$current_repo" = "/" ] || [ "$current_repo" = "\\" ]; then
            current_repo="update"
        fi
        commit_msg="${GIT_COMMIT_PREFIX}: $current_repo"
    fi

    git add .
    
    echo "📌 커밋 메시지: $commit_msg"
    if git commit -m "$commit_msg"; then
        echo "✅ 커밋 완료"
        
        if [ "$GIT_AUTO_PUSH" = true ]; then
            echo "🌐 원격 저장소로 푸시 중..."
            
            # 브랜치 리스트 가져오기
            local branches=$(git branch --list 2>/dev/null | sed 's/^[* ] //' | tr '\n' ' ')
            local has_master=false
            local has_main=false
            local push_branch=""
            local remote_head=""
            local need_select=true

            for branch in $branches; do
                if [ "$branch" = "master" ]; then
                    has_master=true
                elif [ "$branch" = "main" ]; then
                    has_main=true
                fi
            done

            # Prefer remote default branch if available
            remote_head=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
            if [ -z "$remote_head" ]; then
                remote_head=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
            fi

            if [ -n "$remote_head" ]; then
                if [ "$has_master" = true ] && [ "$has_main" = true ]; then
                    need_select=true
                elif [ "$has_master" = false ] && [ "$has_main" = false ]; then
                    need_select=true
                elif [ "$remote_head" = "master" ] && [ "$has_master" = true ] && [ "$has_main" = false ]; then
                    push_branch="$remote_head"
                    need_select=false
                elif [ "$remote_head" = "main" ] && [ "$has_main" = true ] && [ "$has_master" = false ]; then
                    push_branch="$remote_head"
                    need_select=false
                else
                    need_select=true
                fi
            fi

            if [ "$need_select" = true ]; then
                # master/main이 동시에 있거나 둘 다 없으면 브랜치 리스트 표시하고 사용자 선택
                echo ""
                echo "📋 사용 가능한 브랜치:"
                local branch_list=$(git branch --list 2>/dev/null | sed 's/^[* ] //')
                local branch_array=()
                local index=1
                
                while IFS= read -r branch; do
                    if [ -n "$branch" ]; then
                        echo "  $index) $branch"
                        branch_array[$index]="$branch"
                        index=$((index + 1))
                    fi
                done <<< "$branch_list"
                
                if [ $index -eq 1 ]; then
                    echo "❌ 사용 가능한 브랜치가 없습니다. 푸시를 건너뜁니다."
                    return 0
                fi
                
                echo ""
                read -p "푸시할 브랜치 번호를 선택하세요 (1-$((index-1))): " branch_choice
                
                if [ -n "$branch_choice" ] && [ "$branch_choice" -ge 1 ] && [ "$branch_choice" -lt "$index" ] 2>/dev/null; then
                    push_branch="${branch_array[$branch_choice]}"
                else
                    echo "❌ 잘못된 선택입니다. 푸시를 건너뜁니다."
                    return 0
                fi
            fi
            
            # 선택된 브랜치로 푸시 시도
            if [ -n "$push_branch" ]; then
                echo "🚀 브랜치 '$push_branch'로 푸시 중..."
                if git push origin "$push_branch" 2>/dev/null; then
                    echo "✅ 푸시 완료! (브랜치: $push_branch)"
                    push_ok=true
                else
                    echo "❌ 푸시 실패 (브랜치: $push_branch)"
                    echo "💡 수동으로 푸시하세요: git push origin $push_branch"
                fi
            fi
        fi
    else
        echo "⚠️  커밋 실패"
        return 1
    fi
    
    echo "📁 상위 폴더로 이동"
    cd .. || {
        echo "⚠️  상위 폴더로 이동할 수 없습니다"
        return 1
    }

    if [ "$ssafy_mode" = true ]; then
        local ssafy_root=""
        ssafy_root=$(_find_ssafy_session_root "$(pwd)" 2>/dev/null || true)
        if [ -z "$ssafy_root" ] && [ -n "${SSAFY_SESSION_ROOT:-}" ] && [ -d "$SSAFY_SESSION_ROOT" ]; then
            ssafy_root="$SSAFY_SESSION_ROOT"
        fi
        if [ -n "$ssafy_root" ]; then
            cd "$ssafy_root" || {
                echo "??  SSAFY 루트로 이동할 수 없습니다: $ssafy_root"
                return 1
            }
        fi
    fi

    if [ "$ssafy_mode" = true ]; then
        if [ "$push_ok" = true ]; then
            local next_repo=$(_ssafy_next_repo "$current_repo")
            if [ -n "$next_repo" ] && [ ! -d "$next_repo" ]; then
                echo "??  다음 문제 레포가 로컬에 없습니다: $next_repo"
                echo "??  SSAFY에서 실습실/과제를 생성해야 레포가 만들어질 수 있습니다."
            fi
            if [ -n "$next_repo" ] && [ -d "$next_repo" ]; then
                echo "➡️  다음 문제로 이동: $next_repo"
                _open_repo_file "$next_repo" || echo "⚠️  다음 디렉터리로 이동할 수 없습니다: $next_repo"
            else
                if [[ "$current_repo" =~ ^([A-Za-z0-9]+)_(ws|hw|ex)_([0-9]+)(_[0-9]+)?$ ]]; then
                    local topic="${BASH_REMATCH[1]}"
                    local session="${BASH_REMATCH[3]}"
                    echo ""
                    echo "🎉 [${topic}] 과목의 해당 [${session}]차시가 종료되었습니다. 고생하셨습니다"
                else
                    echo "⚠️  다음 문제를 찾을 수 없습니다."
                fi
            fi
        else
            echo "⚠️  푸시 실패/미실행으로 다음 문제 이동을 건너뜁니다."
        fi
    fi
}

# =============================================================================
# gitup - Git 저장소 클론 및 시작
# =============================================================================

_open_repo_file() {
    local repo_dir="$1"

    if [ ! -d "$repo_dir" ]; then
        echo "⚠️  디렉터리를 찾을 수 없습니다: $repo_dir"
        return 1
    fi

    cd "$repo_dir" || return 1

    local target_file=""
    local file_types=("*.py" "*.html" "README*" "*.js" "*.css" "*.json" "*.md" "*.txt")

    for pattern in "${file_types[@]}"; do
        target_file=$(find . -maxdepth 2 -name "$pattern" -type f | head -n 1)
        if [ -n "$target_file" ]; then
            echo "📄 파일 발견: $target_file"
            break
        fi
    done

    if [ -n "$target_file" ]; then
        local editor=$(get_active_ide)
        echo "📌 감지된 IDE: $editor"
        echo "🎉 에디터에서 파일 열기..."
        _open_in_editor "$editor" "$target_file"
    else
        echo "⚠️  적절한 파일을 찾을 수 없습니다"
        echo "📋 클론된 폴더 내용:"
        ls -la
    fi

    echo "✅ 프로젝트 준비 완료!"
}

_gitup_ssafy() {
    local input="$1"

    _ensure_ssafy_config
    if [ -z "${SSAFY_BASE_URL:-}" ] || [ -z "${SSAFY_USER_ID:-}" ]; then
        echo "?? SSAFY 설정이 필요합니다. 'algo-config edit'로 SSAFY_BASE_URL/SSAFY_USER_ID를 설정하세요."
        return 1
    fi

    local base_url="${SSAFY_BASE_URL%/}"
    local user_id="${SSAFY_USER_ID%/}"
    local repo_name="$input"
    local topic=""
    local session=""

    if [[ "$input" =~ ^https?:// ]]; then
        repo_name=$(basename "$input")
        repo_name="${repo_name%.git}"
    fi

    if [[ "$repo_name" =~ ^([A-Za-z0-9]+)_(ws|hw)_([0-9]+)_[0-9]+$ ]]; then
        topic="${BASH_REMATCH[1]}"
        session="${BASH_REMATCH[3]}"
    elif [[ "$repo_name" =~ ^([A-Za-z0-9]+)_(ws|hw)_([0-9]+)$ ]]; then
        topic="${BASH_REMATCH[1]}"
        session="${BASH_REMATCH[3]}"
    elif [[ "$repo_name" =~ ^([A-Za-z0-9]+)_(ws|hw)$ ]]; then
        topic="${BASH_REMATCH[1]}"
        read -r -p "차시 입력: " session
    elif [[ "$repo_name" =~ ^([A-Za-z0-9]+)$ ]]; then
        topic="$repo_name"
        read -r -p "차시 입력: " session
    else
        if [[ "$repo_name" =~ ^(ws|hw)_[0-9]+(_[0-9]+)?$ ]]; then
            echo "?? SSAFY 입력 형식이 올바르지 않습니다: $repo_name"
            echo "   예: <topic>_ws_<차시> 또는 <topic>_ws_<차시>_<번호>"
            echo "   예: ds_ws_2 또는 ds_ws_2_1"
        fi
        return 1
    fi

    if [ -z "$session" ] || ! [[ "$session" =~ ^[0-9]+$ ]]; then
        echo "❗ 차시 번호가 올바르지 않습니다."
        return 1
    fi

    local repos=()
    local i=""
    for i in 1 2 3 4 5; do
        repos+=("${topic}_ws_${session}_${i}")
    done
    for i in 2 4; do
        repos+=("${topic}_hw_${session}_${i}")
    done

    local -a cloned=()
    local -a skipped=()
    local -a failed=()
    local repo=""

    for repo in "${repos[@]}"; do
        local url="${base_url}/${user_id}/${repo}"
        if [ -d "$repo" ]; then
            skipped+=("$repo")
            continue
        fi
        if git clone "$url" >/dev/null 2>&1; then
            cloned+=("$repo")
        else
            failed+=("$repo")
        fi
    done

    echo "Clone summary: ok=${#cloned[@]}, skipped=${#skipped[@]}, failed=${#failed[@]}"
    if [ "${#failed[@]}" -gt 0 ]; then
        echo "Failed: ${failed[*]}"
    fi

    local session_root="$(pwd)"
    export SSAFY_SESSION_ROOT="$session_root"
    {
        echo "topic=$topic"
        echo "session=$session"
        echo "user_id=$user_id"
        echo "base_url=$base_url"
    } > "$session_root/.ssafy_session_root" 2>/dev/null || true

    local first_repo="${topic}_ws_${session}_1"
    if [ -d "$first_repo" ]; then
        _open_repo_file "$first_repo"
    elif [ "${#cloned[@]}" -gt 0 ]; then
        _open_repo_file "${cloned[0]}"
    elif [ "${#skipped[@]}" -gt 0 ]; then
        _open_repo_file "${skipped[0]}"
    else
        echo "No repository to open."
    fi
}

_ssafy_next_repo() {
    local repo_name="$1"
    
    # [Playlist] 순서 파일이 있으면 우선 사용
    # 현재 폴더(SSAFY 세션 루트)에 .ssafy_playlist 확인
    if [ -f ".ssafy_playlist" ]; then
        local -a playlist=()
        while IFS= read -r line; do
            # 윈도우 줄바꿈(\r) 제거
            line="${line//$'\r'/}"
            if [ -n "$line" ]; then
                playlist+=("$line")
            fi
        done < ".ssafy_playlist"
        
        local i
        for i in "${!playlist[@]}"; do
            if [ "${playlist[$i]}" == "$repo_name" ]; then
                local next_idx=$((i + 1))
                if [ -n "${playlist[$next_idx]}" ]; then
                    echo "${playlist[$next_idx]}"
                    return 0
                fi
            fi
        done
    fi

    local topic=""
    local kind=""
    local session=""
    local number=""

    if ! [[ "$repo_name" =~ ^([A-Za-z0-9]+)_(ws|hw)_([0-9]+)_([0-9]+)$ ]]; then
        return 1
    fi

    topic="${BASH_REMATCH[1]}"
    kind="${BASH_REMATCH[2]}"
    session="${BASH_REMATCH[3]}"
    number="${BASH_REMATCH[4]}"

    if [ "$kind" = "ws" ]; then
        if [ "$number" -lt 5 ]; then
            number=$((number + 1))
            echo "${topic}_ws_${session}_${number}"
            return 0
        elif [ "$number" -eq 5 ]; then
            echo "${topic}_hw_${session}_2"
            return 0
        fi
    elif [ "$kind" = "hw" ]; then
        if [ "$number" -eq 2 ]; then
            echo "${topic}_hw_${session}_4"
            return 0
        fi
    fi

    return 1
}
gitup() {
    init_algo_config

    local ssafy_mode=false
    local input=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --ssafy|-s) ssafy_mode=true ;;
            *)
                if [ -z "$input" ]; then
                    input="$1"
                else
                    echo "❗️사용법: gitup <git-repository-url | ssafy-topic>"
                    echo "예시:"
                    echo "  gitup https://github.com/user/repo.git"
                    echo "  gitup data_ws"
                    echo "  gitup https://lab.ssafy.com/${SSAFY_USER_ID}/data_ws_4_1"
                    echo "  gitup --ssafy data_ws"
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [ -z "$input" ]; then
        echo "❗️사용법: gitup <git-repository-url | ssafy-topic>"
        echo "예시:"
        echo "  gitup https://github.com/user/repo.git"
        echo "  gitup data_ws"
        echo "  gitup https://lab.ssafy.com/${SSAFY_USER_ID}/data_ws_4_1"
        echo "  gitup --ssafy data_ws"
        return 1
    fi

    local ssafy_detected=false
    if [ "$ssafy_mode" = true ]; then
        ssafy_detected=true
    elif [[ "$input" =~ ^https?://lab\.ssafy\.com/ ]]; then
        ssafy_detected=true
    fi

    # 0. SSAFY 실습실 생성 URL 감지 (https://project.ssafy.com/...)
    if [[ "$input" == https://project.ssafy.com/* ]]; then
        echo "🚀 SSAFY 실습실 일괄 생성 및 클론 모드 (Smart Batch)"
        echo "⏳ 실습실 생성 및 URL 분석 중..."
        
        # 파이썬 스크립트 실행 (Pipe 모드)
        # 결과: 생성된/유추된 레포 URL들이 줄바꿈으로 출력됨
        local -a repos=()
        while IFS= read -r line; do
            # Windows 호환: \r 제거
            line="${line//$'\r'/}"
            # 빈 줄이나 공백 제외
            if [ -n "${line//[[:space:]]/}" ]; then
                repos+=("$line")
            fi
        # 스크립트 위치 동적 감지
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        done < <(python "$script_dir/ssafy_batch_create.py" "$input" 12 --pipe)
        
        if [ "${#repos[@]}" -eq 0 ]; then
            echo "❌ 생성된 실습실이 없거나 URL 분석에 실패했습니다."
            return 1
        fi
        
    # [Playlist] .ssafy_playlist 파일 생성
    # 파이썬에서 받은 URL 목록을 기반으로 순서 파일 생성
    if [ "${#repos[@]}" -gt 0 ]; then
        rm -f .ssafy_playlist
        for r_url in "${repos[@]}"; do
            # URL에서 마지막 부분(디렉토리명) 추출
            local dname=$(basename "$r_url")
            dname="${dname%.git}"
            echo "$dname" >> .ssafy_playlist
        done
        echo "📋 자동 이동 순서 생성됨 (.ssafy_playlist)"
    fi
        
    local first_dir=""
    local priority_dir=""
    
    for repo_url in "${repos[@]}"; do
        echo "⬇️  Clone: $repo_url"
            # 백그라운드 말고 순차 실행 (오류 확인 위해)
            # 이미 있으면 git clone이 알아서 에러/패스 처리함
            git clone "$repo_url"
            
            # 디렉토리명 추출
            local dname=$(basename "$repo_url" .git)
            
            # 첫 번째 발견된 폴더 저장 (Fallback)
            if [ -z "$first_dir" ] && [ -d "$dname" ]; then
                first_dir="$dname"
            fi
            
            # 우선순위: 이름이 _1 로 끝나는 폴더 (예: vue_ws_3_1)
            # 여러 개일 경우 가장 먼저 발견된 _1 (보통 ex_1)
            if [ -z "$priority_dir" ] && [ -d "$dname" ] && [[ "$dname" == *_1 ]]; then
                priority_dir="$dname"
            fi
        done
        
        echo "✅ 일괄 작업 완료!"
        
        # 우선순위 폴더가 있으면 교체
        if [ -n "$priority_dir" ]; then
            first_dir="$priority_dir"
        fi
        
        if [ -n "$first_dir" ]; then
            echo "👉 첫 번째 문제로 이동합니다: $first_dir"
            _open_repo_file "$first_dir"
            return 0
        else
            echo "⚠️  클론된 디렉토리를 찾을 수 없습니다."
            return 1
        fi
    fi

    # 1. SSAFY Topic 감지 (예: ws_3_1, data_ws 등)
    if [[ "$input" =~ ^[A-Za-z0-9]+_(ws|hw)(_[0-9]+(_[0-9]+)?)?$ ]]; then
        _gitup_ssafy "$input" || return 1
        return 0
    fi
    
    echo "🔄 Git 저장소 클론 중: $input"
    git clone "$input" || return 1
    
    local repo_name=$(basename "$input" .git)
    _open_repo_file "$repo_name"
}

# =============================================================================
# get_active_ide - 활성 IDE 감지
# =============================================================================
get_active_ide() {
    init_algo_config
    
    local os_type=""
    
    # 운영체제 감지
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || command -v powershell.exe > /dev/null 2>&1; then
        os_type="windows"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os_type="mac"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os_type="linux"
    fi
    
    # 설정된 우선순위에 따라 IDE 검색
    for ide in $IDE_PRIORITY; do
        case "$os_type" in
            "windows")
                local process_name="${ide}*"
                if powershell.exe -Command "Get-Process | Where-Object {\$_.ProcessName -like '$process_name'}" 2>/dev/null | grep -q "$ide"; then
                    case "$ide" in
                        pycharm) echo "pycharm64.exe" ;;
                        idea) echo "idea64.exe" ;;
                        *) echo "$ide" ;;
                    esac
                    return
                fi
                ;;
            "mac")
                if pgrep -f "$ide" > /dev/null; then
                    echo "$ide"
                    return
                fi
                ;;
            "linux")
                if pgrep -f "$ide" > /dev/null; then
                    echo "${ide}.sh"
                    return
                fi
                ;;
        esac
    done
    
    # 기본값
    echo "code"
}

# =============================================================================
# check_ide - IDE 디버깅 정보
# =============================================================================
check_ide() {
    init_algo_config
    
    echo "🔍 IDE 감지 디버깅 정보:"
    echo ""
    echo "💻 운영체제: $OSTYPE"
    echo "📁 현재 위치: $(pwd)"
    echo ""
    
    # 운영체제 감지
    local os_type=""
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || command -v powershell.exe > /dev/null 2>&1; then
        os_type="windows"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os_type="mac"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os_type="linux"
    fi
    
    echo "1️⃣ 실행 중인 IDE 프로세스:"
    case "$os_type" in
        "windows")
            # Windows: tasklist 또는 PowerShell 사용
            if command -v tasklist > /dev/null 2>&1; then
                local ide_processes=$(tasklist 2>/dev/null | grep -iE "(code|pycharm|idea|subl)" || echo "")
                if [ -n "$ide_processes" ]; then
                    echo "$ide_processes" | head -10
                else
                    echo "   ❌ IDE 프로세스를 찾을 수 없습니다"
                fi
            elif command -v powershell.exe > /dev/null 2>&1; then
                local ide_processes=$(powershell.exe -Command "Get-Process | Where-Object {\$_.ProcessName -like '*code*' -or \$_.ProcessName -like '*pycharm*' -or \$_.ProcessName -like '*idea*' -or \$_.ProcessName -like '*subl*'} | Select-Object ProcessName,Id" 2>/dev/null)
                if [ -n "$ide_processes" ]; then
                    echo "$ide_processes"
                else
                    echo "   ❌ IDE 프로세스를 찾을 수 없습니다"
                fi
            else
                echo "   ⚠️  프로세스 확인 도구를 찾을 수 없습니다"
            fi
            ;;
        "mac"|"linux")
            # macOS/Linux: ps 또는 pgrep 사용
            if command -v pgrep > /dev/null 2>&1; then
                local ide_found=false
                for ide in code pycharm idea subl; do
                    if pgrep -f "$ide" > /dev/null 2>&1; then
                        echo "   ✅ $ide 실행 중"
                        ide_found=true
                    fi
                done
                if [ "$ide_found" = false ]; then
                    echo "   ❌ IDE 프로세스를 찾을 수 없습니다"
                fi
            elif command -v ps > /dev/null 2>&1; then
                local ide_processes=$(ps aux 2>/dev/null | grep -E "(pycharm|idea|code|subl)" | grep -v grep || echo "")
                if [ -n "$ide_processes" ]; then
                    echo "$ide_processes" | head -10
                else
                    echo "   ❌ IDE 프로세스를 찾을 수 없습니다"
                fi
            else
                echo "   ⚠️  프로세스 확인 도구를 찾을 수 없습니다"
            fi
            ;;
        *)
            echo "   ⚠️  알 수 없는 운영체제"
            ;;
    esac
    
    echo ""
    echo "2️⃣ get_active_ide() 결과:"
    local detected_ide=$(get_active_ide)
    echo "   감지된 IDE: '$detected_ide'"
    
    echo ""
    echo "3️⃣ IDE 명령어 확인:"
    for ide in $IDE_PRIORITY; do
        local ide_cmd="$ide"
        case "$ide" in
            pycharm)
                if [ "$os_type" = "windows" ]; then
                    ide_cmd="pycharm64.exe"
                elif [ "$os_type" = "linux" ]; then
                    ide_cmd="pycharm.sh"
                fi
                ;;
            idea)
                if [ "$os_type" = "windows" ]; then
                    ide_cmd="idea64.exe"
                elif [ "$os_type" = "linux" ]; then
                    ide_cmd="idea.sh"
                fi
                ;;
        esac
        
        if command -v "$ide_cmd" > /dev/null 2>&1; then
            echo "   ✅ $ide ($ide_cmd) - 설치됨"
        else
            echo "   ❌ $ide ($ide_cmd) - 설치되지 않음"
        fi
    done
    
    echo ""
    echo "4️⃣ 현재 설정:"
    algo_config show | grep "IDE_PRIORITY" || echo "   설정 파일을 찾을 수 없습니다"
    
    echo ""
    echo "💡 IDE 우선순위를 변경하려면: algo-config edit"
}

# =============================================================================
# gitup - 파일 선택(override)
# =============================================================================

_open_repo_file() {
    local repo_dir="$1"

    if [ ! -d "$repo_dir" ]; then
        echo "??  디렉터리를 찾을 수 없습니다: $repo_dir"
        return 1
    fi

    cd "$repo_dir" || return 1

    local editor
    editor=$(get_active_ide)

    local maxdepth=6
    local -a primary_files=()

    while IFS= read -r -d '' f; do
        f="${f#./}"
        primary_files+=("$f")
    done < <(
        find . -maxdepth "$maxdepth" \
            \( -path './.git' -o -path './.git/*' -o -path './.vscode' -o -path './.vscode/*' -o -path './.idea' -o -path './.idea/*' -o -path './node_modules' -o -path './node_modules/*' -o -path './venv' -o -path './venv/*' -o -path './.venv' -o -path './.venv/*' -o -path './__pycache__' -o -path './__pycache__/*' \) -prune -o \
            -type f \( -name '*.py' -o -name '*.ipynb' -o -name '*.cpp' -o -name '*.vue' -o -name '*.js' -o -name '*.html' -o -name '*.css' -o -name '*.java' \) -print0 2>/dev/null
    )

    local chosen=""

    if _is_interactive; then
        while true; do
            echo ""
            echo "============================================================"
            echo " 📂 [Code Selector] 자주 사용하는 파일"
            echo "============================================================"
            if [ "${#primary_files[@]}" -gt 0 ]; then
                local i=""
                for i in "${!primary_files[@]}"; do
                    printf "  %2d. %s\n" "$((i + 1))" "${primary_files[$i]}"
                done
            else
                echo "  (추천 파일 없음)"
            fi

            echo "------------------------------------------------------------"
            echo "  t. 🌳 전체 파일 트리 보기"
            echo "  q. ❌ 취소"
            echo "============================================================"

            local choice=""
            read -r -p "👉 원하시는 파일 번호 또는 메뉴를 입력하세요: " choice

            if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
                return 1
            fi

            if [ "$choice" = "t" ] || [ "$choice" = "T" ]; then
                local -a all_files=()
                while IFS= read -r -d '' af; do
                    af="${af#./}"
                    case "$af" in
                        .git/*|.git|.vscode/*|.idea/*|node_modules/*|venv/*|.venv/*|__pycache__/*) continue ;;
                        *.iml|*.code-workspace|.DS_Store) continue ;;
                        .gitignore|.gitattributes|.editorconfig|.env|.env.*) continue ;;
                    esac
                    all_files+=("$af")
                done < <(
                    find . -maxdepth "$maxdepth" \
                        \( -path './.git' -o -path './.git/*' -o -path './node_modules' -o -path './node_modules/*' -o -path './venv' -o -path './venv/*' -o -path './.venv' -o -path './.venv/*' \) -prune -o \
                        -type f -print0 2>/dev/null
                )

                if [ "${#all_files[@]}" -eq 0 ]; then
                    echo "⚠️  열 수 있는 파일을 찾을 수 없습니다."
                    continue
                fi

                echo ""
                echo "============================================================"
                echo " 🌳 [File Tree] 전체 파일 목록"
                echo "============================================================"
                local j=""
                for j in "${!all_files[@]}"; do
                    printf "  %2d. %s\n" "$((j + 1))" "${all_files[$j]}"
                done
                echo "------------------------------------------------------------"
                echo "  b. 🔙 뒤로 가기"
                echo "  q. ❌ 취소"
                echo "============================================================"

                local tchoice=""
                read -r -p "👉 번호를 입력하세요: " tchoice

                if [ "$tchoice" = "q" ] || [ "$tchoice" = "Q" ]; then
                    return 1
                fi
                if [ "$tchoice" = "b" ] || [ "$tchoice" = "B" ]; then
                    continue
                fi
                if [[ "$tchoice" =~ ^[0-9]+$ ]] && [ "$tchoice" -ge 1 ] && [ "$tchoice" -le "${#all_files[@]}" ]; then
                    chosen="${all_files[$((tchoice - 1))]}"
                    break
                fi

                echo "⚠️  잘못된 선택입니다."
                continue
            fi

            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#primary_files[@]}" ]; then
                chosen="${primary_files[$((choice - 1))]}"
                break
            fi

            echo "⚠️  잘못된 선택입니다."
        done
    else
        if [ "${#primary_files[@]}" -gt 0 ]; then
            chosen="${primary_files[0]}"
        else
            chosen="$(find . -maxdepth 2 -type f | head -n 1)"
            chosen="${chosen#./}"
        fi
    fi

    if [ -n "$chosen" ] && [ -f "$chosen" ]; then
        echo "?? 감지된 IDE: $editor"
        echo "?? 에디터에서 파일 열기: $chosen"
        _open_in_editor "$editor" "$chosen"
    else
        echo "??  열 파일을 찾을 수 없습니다"
        echo "?? 클론된 폴더 내용:"
        ls -la
    fi

    echo "? 프로젝트 준비 완료!"
}

# =============================================================================
# 초기화 실행
# =============================================================================
# =============================================================================
# ssafy_batch - SSAFY 실습실 일괄 자동 생성 (Blind Mode)
# =============================================================================
ssafy_batch() {
    if [ $# -eq 0 ]; then
        echo "Usage: ssafy_batch <URL> [COUNT=7]"
        echo "Example: ssafy_batch \"https://project.ssafy.com/.../PR00147645/...\" 7"
        return 1
    fi
    
    # 설정 파일 로드
    if [ -f "$ALGO_CONFIG_FILE" ]; then
        source "$ALGO_CONFIG_FILE"
    fi
    
    # 토큰 초기화 확인 (없으면 Python 스크립트에서 로그인 진행)
    if [ -n "$SSAFY_AUTH_TOKEN" ] && [[ "$SSAFY_AUTH_TOKEN" != "Bearer your_token_here" ]]; then
        export SSAFY_AUTH_TOKEN
    fi
    
    # 현재 스크립트(알고리즘 함수 파일)가 위치한 디렉토리 파악
    # (source 되는 경우 BASH_SOURCE 사용)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Python 스크립트 실행 (동일 디렉토리에 있다고 가정)
    if [ ! -f "$script_dir/ssafy_batch_create.py" ]; then
        echo "❌ 실행 오류: '$script_dir/ssafy_batch_create.py' 파일을 찾을 수 없습니다."
        echo "   algo_functions.sh와 ssafy_batch_create.py는 같은 폴더에 있어야 합니다."
        return 1
    fi
    
    python "$script_dir/ssafy_batch_create.py" "$1" "$2"
}

init_algo_config
_check_update

echo "✅ 알고리즘 셸 함수 로드 완료! (${ALGO_FUNCTIONS_VERSION})"
echo "💡 'algo-config edit'로 설정을 변경할 수 있습니다"
