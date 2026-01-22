#!/bin/bash

# 이전에 정의된 함수/별칭이 남아 있을 때 새 버전을 확실히 적용하기 위해 초기화
{ unalias -- al gitup gitdown algo-config 2>/dev/null || true; }
{ unset -f -- al gitup gitdown algo_config get_active_ide check_ide _confirm_commit_message _create_algo_file _handle_git_commit _open_in_editor _open_repo_file _gitup_ssafy _ssafy_next_repo init_algo_config _is_interactive _set_config_value _ensure_ssafy_config _find_ssafy_session_root _print_file_menu _choose_file_from_list 2>/dev/null || true; }


# =============================================================================
# 알고리즘 문제 풀이 자동화 셸 함수 (공개용)
# =============================================================================

# 설정 파일 경로
ALGO_CONFIG_FILE="$HOME/.algo_config"
ALGO_FUNCTIONS_VERSION="V6.1"

# 업데이트 명령어
algo-update() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    echo "🔄 최신 버전으로 업데이트 중..."
    (
        cd "$script_dir" || exit 1
        git pull origin main
    )
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ 업데이트 완료!"
        read -r -p "🎉 Enter를 누르면 변경사항을 적용합니다..." _
        exec bash
    else
        echo "❌ 업데이트 실패. 직접 'cd $script_dir && git pull'을 시도해보세요."
    fi
}

# 업데이트 알림 체크 (하루 1회, 백그라운드)
ALGO_UPDATE_CHECK_FILE="$HOME/.algo_update_last_check"

_check_update() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # .git 디렉토리가 없으면 패스
    if [ ! -d "$script_dir/.git" ]; then
        return 0
    fi

    # 하루에 한 번만 체크
    if [ -f "$ALGO_UPDATE_CHECK_FILE" ]; then
        local last_check
        last_check=$(cat "$ALGO_UPDATE_CHECK_FILE" 2>/dev/null || echo 0)
        local current_time
        current_time=$(date +%s)
        local diff=$((current_time - last_check))
        
        # 86400초 = 24시간
        if [ $diff -lt 86400 ]; then
            return 0
        fi
    fi

    # 백그라운드에서 체크
    if command -v git > /dev/null 2>&1; then
        (
            cd "$script_dir" || exit
            # timeout 명령어가 있으면 사용, 없으면 그냥 실행 (백그라운드이므로)
            if command -v timeout > /dev/null 2>&1; then
                git_cmd="timeout 2s git fetch origin main"
            else
                git_cmd="git fetch origin main"
            fi
            
            if $git_cmd > /dev/null 2>&1; then
                local local_hash remote_hash
                local_hash=$(git rev-parse HEAD 2>/dev/null)
                remote_hash=$(git rev-parse origin/main 2>/dev/null)
                
                if [ -n "$local_hash" ] && [ -n "$remote_hash" ] && [ "$local_hash" != "$remote_hash" ]; then
                    echo ""
                    echo "📦 [Update] 새로운 버전이 있습니다! (현재: $ALGO_FUNCTIONS_VERSION)"
                    echo "   👉 'algo-update'를 실행하여 업데이트하세요."
                    echo ""
                fi
                # 체크 시간 기록
                date +%s > "$ALGO_UPDATE_CHECK_FILE"
            fi
        ) &
        disown 2>/dev/null || true  # 백그라운드 작업 완료 메시지 억제 (비대화형 쉘 호환)
    fi
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
            read -r -p "SSAFY GitLab 사용자명 (lab.ssafy.com/{여기} 부분): " input
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
# 기본 설정 초기화
init_algo_config() {
    local ide_selection="code"

    if [ ! -f "$ALGO_CONFIG_FILE" ]; then
        if _is_interactive; then
            echo "👋 환영합니다! SSAFY 알고리즘 셸 함수 초기 설정을 진행합니다."
            echo "🔧 주로 사용할 IDE를 선택해주세요:"
            echo "  1) VS Code (code) [기본값]"
            echo "  2) PyCharm (pycharm)"
            echo "  3) IntelliJ IDEA (idea)"
            echo -n "👉 선택 (Example: 1 또는 code): "
            read -r ide_choice
            case "$ide_choice" in
                2|pycharm) ide_selection="pycharm" ;;
                3|idea) ide_selection="idea" ;;
                *) ide_selection="code" ;;
            esac
            echo "✅ '$ide_selection'가 선택되었습니다."
            echo ""
        fi

        cat > "$ALGO_CONFIG_FILE" << EOF
# 알고리즘 문제 풀이 디렉토리 설정
ALGO_BASE_DIR="\$HOME/algorithm"

# Git 설정
GIT_DEFAULT_BRANCH="main"
GIT_COMMIT_PREFIX="solve"
GIT_AUTO_PUSH=true

# IDE 설정 (지원: code, pycharm, idea)
IDE_EDITOR="$ide_selection"

# SSAFY 설정 (처음 실행 시 입력받아 저장합니다)
SSAFY_BASE_URL=""
SSAFY_USER_ID=""
SSAFY_AUTH_TOKEN="Bearer your_token_here"
EOF
        echo "✅ 설정 파일 생성: $ALGO_CONFIG_FILE"
        echo "💡 'algo-config' 명령어로 설정을 변경할 수 있습니다"
    fi
    
    source "$ALGO_CONFIG_FILE"
    
    # [Security V7.0] 파일 권한 600 강제 (타인 접근 제한)
    chmod 600 "$ALGO_CONFIG_FILE" 2>/dev/null || true

    # [Security V7.0] 토큰 암호화 관리 (Base64)
    # 1. 평문(Bearer ...)이면 -> Base64로 인코딩하여 파일에 저장 (마이그레이션)
    # 2. 암호문이면 -> 디코딩하여 메모리($SSAFY_AUTH_TOKEN)에 로드
    if [ -n "${SSAFY_AUTH_TOKEN:-}" ] && [[ "${SSAFY_AUTH_TOKEN:-}" != "Bearer your_token_here" ]]; then
        if [[ "$SSAFY_AUTH_TOKEN" == "Bearer "* ]]; then
            # 마이그레이션: 평문 -> Base64
            if command -v base64 >/dev/null 2>&1; then
                local encoded_token=$(echo -n "$SSAFY_AUTH_TOKEN" | base64 | tr -d '\n')
                # sed로 파일 업데이트
                # (특수문자 처리를 위해 구분자를 | 사용)
                if sed --version >/dev/null 2>&1; then
                    sed -i "s|^SSAFY_AUTH_TOKEN=.*|SSAFY_AUTH_TOKEN=\"$encoded_token\"|" "$ALGO_CONFIG_FILE"
                else
                    sed -i '' "s|^SSAFY_AUTH_TOKEN=.*|SSAFY_AUTH_TOKEN=\"$encoded_token\"|" "$ALGO_CONFIG_FILE"
                fi
                echo "🔐 [보안] 토큰이 안전하게 암호화되었습니다."
            fi
        else
            # 디코딩: Base64 -> 평문
            if command -v base64 >/dev/null 2>&1; then
                # base64 -d가 실패할 경우 대비
                local decoded_token=$(echo "$SSAFY_AUTH_TOKEN" | base64 -d 2>/dev/null || echo "")
                if [[ "$decoded_token" == "Bearer "* ]]; then
                    SSAFY_AUTH_TOKEN="$decoded_token"
                fi
            fi
        fi
    fi
    
    # 마이그레이션: IDE_EDITOR가 없는 경우 (V6 -> V6.1)
    if [ -z "${IDE_EDITOR:-}" ]; then
        # 기존 우선순위에서 첫 번째 가져오기
        local legacy_ide="code"
        if [ -n "${IDE_PRIORITY:-}" ]; then
            legacy_ide=$(echo "$IDE_PRIORITY" | awk '{print $1}')
        fi
        
        if _is_interactive; then
            echo ""
            echo "📢 [V6.1 업데이트] IDE 설정 방식이 변경되었습니다."
            echo "🔧 기본 IDE를 하나만 선택해주세요:"
            echo "  1) VS Code (code)"
            if [ "$legacy_ide" != "code" ]; then
                echo "  2) PyCharm (pycharm)"
                echo "  3) IntelliJ IDEA (idea)"
                echo -n "👉 선택 (Enter=${legacy_ide}): "
            else
                echo "  2) PyCharm (pycharm)"
                echo "  3) IntelliJ IDEA (idea)"
                echo -n "👉 선택 (Enter=code): "
            fi
            
            read -r ide_choice
            case "$ide_choice" in
                2|pycharm) ide_selection="pycharm" ;;
                3|idea) ide_selection="idea" ;;
                1|code) ide_selection="code" ;;
                *) ide_selection="$legacy_ide" ;;
            esac
            
            # 설정 파일에 추가
            {
                echo ""
                echo "# IDE 설정 (V6.1 업데이트)"
                echo "IDE_EDITOR=\"$ide_selection\""
            } >> "$ALGO_CONFIG_FILE"
            
            IDE_EDITOR="$ide_selection"
            echo "✅ 설정이 업데이트되었습니다: IDE_EDITOR=$IDE_EDITOR"
        fi
    fi
    
    # [Cleanup] V6.1 이후 레거시 설정 제거 (IDE_PRIORITY)
    if [ -n "${IDE_EDITOR:-}" ] && grep -q "IDE_PRIORITY=" "$ALGO_CONFIG_FILE"; then
        # IDE_PRIORITY 줄 제거
        if sed --version >/dev/null 2>&1; then
            # GNU sed
            sed -i '/IDE_PRIORITY=/d' "$ALGO_CONFIG_FILE"
            sed -i '/# IDE 우선순위/d' "$ALGO_CONFIG_FILE"
        else
            # BSD sed (macOS)
            sed -i '' '/# IDE 우선순위/d' "$ALGO_CONFIG_FILE" 2>/dev/null || true
        fi
    fi

    # [Cleanup] 설정 파일 포맷 정리 (주석 수정 및 섹션 간격 복구)
    if [ -f "$ALGO_CONFIG_FILE" ]; then
        # 1. "(V6.1 업데이트)" 문구 제거
        if grep -q "(V6.1 업데이트)" "$ALGO_CONFIG_FILE"; then
             if sed --version >/dev/null 2>&1; then
                sed -i 's/# IDE 설정 (V6.1 업데이트)/# IDE 설정/g' "$ALGO_CONFIG_FILE"
            else
                sed -i '' 's/# IDE 설정 (V6.1 업데이트)/# IDE 설정/g' "$ALGO_CONFIG_FILE" 2>/dev/null || true
            fi
        fi
        
        # 2. 섹션 간 줄바꿈 복구 및 정규화 (awk 사용)
        # - 주요 섹션 헤더(# ...) 앞에 빈 줄이 없으면 추가
        # - 연속된 빈 줄은 1개로 축소
        awk '
            /^# (Git|SSAFY|IDE) 설정/ { print "" } 
            { print $0 }
        ' "$ALGO_CONFIG_FILE" | awk '
            !NF { if (++n <= 1) print; next } 
            { n=0; print }
        ' > "$ALGO_CONFIG_FILE.tmp" && mv "$ALGO_CONFIG_FILE.tmp" "$ALGO_CONFIG_FILE"
    fi
    
    # Python 스크립트를 위해 토큰 자동 export
    if [ -n "${SSAFY_AUTH_TOKEN:-}" ] && [[ "${SSAFY_AUTH_TOKEN:-}" != "Bearer your_token_here" ]]; then
        export SSAFY_AUTH_TOKEN
    fi
    
    _ensure_ssafy_config
}

# 설정 편집 명령어
algo_config() {
    init_algo_config
    
    if [ "$1" = "edit" ]; then
        # V7.0: Python 마법사 사용
        local script_dir
        # BASH_SOURCE[0]는 함수 호출 시점에 따라 다를 수 있으나, 일반적으로 source된 위치를 찾으려면
        # 현재 함수가 정의된 파일을 추적해야 함. 하지만 복잡하므로
        # ALGO_BASE_DIR 혹은 algo_functions.sh 경로를 환경변수에서 유추?
        # 가장 확실한 건 algo_functions.sh 파일 내에서 상단 전역 변수로 HOME을 잡아두는 것인데...
        # 일단 ssafy_batch 처럼 구해봄.
        
        # 주의: source된 상태에서 BASH_SOURCE[0]는 셸 자체일 수도 있음.
        # 그러나 함수 내에서는 BASH_SOURCE[0]가 스크립트 경로를 가리킬 가능성 높음(bash 특성).
        # 안되면 사용자 홈의 특정 위치 가정 (~/.ssafy-tools/algo_functions.sh? 아니면 현재 경로?)
        # 사용자는 ~/Desktop/SSAFY_sh_func에 있음.
        
        # 임시: 현재 작업 디렉토리에 있다고 가정하지 말고, locate 시도
        script_dir="$HOME/Desktop/SSAFY_sh_func" # 기본값 (사용자 환경)
        
        # 더 나은 방법: gitup 등에서 이미 SCRIPT_DIR를 알 수 있다면 좋겠지만..
        # 단순히 $HOME/.ssafy-tools/algo_config_wizard.py 가 배포될 것임 (git pull 시)
        # 사용자는 ~/.ssafy-tools 를 source 하고 있음.
        if [ -f "$HOME/.ssafy-tools/algo_config_wizard.py" ]; then
            script_dir="$HOME/.ssafy-tools"
        elif [ -f "$HOME/Desktop/SSAFY_sh_func/algo_config_wizard.py" ]; then
            script_dir="$HOME/Desktop/SSAFY_sh_func"
        fi
        
        python "$script_dir/algo_config_wizard.py"
        echo "✅ 설정 변경이 완료되었습니다. 변경 사항 적용을 위해 'source ~/.bashrc'를 실행해주세요."
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
            if [ "$skip_git" = false ]; then
                _handle_git_commit "$file" "$problem" "$custom_commit_msg" "$lang"
            else
                echo "⏭️  Git 작업 건너뛰기"
            fi
        fi
    else
        if [ "$has_py" = false ] && [ "$has_cpp" = false ]; then
            file="$py_file"
            lang="py"
            _create_algo_file "$file" "$site_name" "$site_display" "$problem" "$lang"
        else
            if [ "$skip_git" = false ]; then
                if [ "$has_py" = true ]; then
                    _handle_git_commit "$py_file" "$problem" "$custom_commit_msg" "py"
                fi
                if [ "$has_cpp" = true ]; then
                    _handle_git_commit "$cpp_file" "$problem" "$custom_commit_msg" "cpp"
                fi
            else
                echo "⏭️  Git 작업 건너뛰기"
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

# =============================================================================
# Helper: _find_ssafy_session_root
# 현재 위치에서 상위로 이동하며 세션 루트(.ssafy_session_meta 또는 .ssafy_playlist가 있는 곳)를 찾음
# =============================================================================
_find_ssafy_session_root() {
    local dir="$1"
    if [ -z "$dir" ]; then dir=$(pwd); fi
    
    # 순환 방지용
    local count=0
    
    while [ "$dir" != "/" ] && [ "$dir" != "." ] && [ "$count" -lt 10 ]; do
        if [ -f "$dir/.ssafy_session_meta" ] || [ -f "$dir/.ssafy_playlist" ]; then
            echo "$dir"
            return 0
        fi
        
        # Windows Git Bash 호환 (C:/ 등)
        if [[ "$dir" =~ ^[A-Za-z]:/[^/]*$ ]]; then
            # 드라이브 루트면 종료
            if [ -f "$dir/.ssafy_session_meta" ]; then
                echo "$dir"
                return 0
            fi
            return 1
        fi
        
        dir=$(dirname "$dir")
        ((count++))
    done
    return 1
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
    
    # 파일이 있는 디렉토리를 통째로 add (sample_input.txt 등 포함)
    local relative_dir=$(dirname "$relative_path")
    git add "$relative_dir"
    
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
# _gitdown_all - 전체 실습실 일괄 Push
# =============================================================================
_gitdown_all() {
    local ssafy_root=""
    ssafy_root=$(_find_ssafy_session_root "$(pwd)" 2>/dev/null || true)
    
    if [ -z "$ssafy_root" ] && [ -n "${SSAFY_SESSION_ROOT:-}" ] && [ -d "$SSAFY_SESSION_ROOT" ]; then
        ssafy_root="$SSAFY_SESSION_ROOT"
    fi
    
    if [ -z "$ssafy_root" ]; then
        echo "❌ SSAFY 세션 루트를 찾을 수 없습니다."
        echo "💡 gitup으로 실습실을 먼저 생성하세요."
        return 1
    fi
    
    cd "$ssafy_root" || return 1
    echo "📂 세션 루트: $ssafy_root"
    
    # 폴더 목록 수집 (playlist 또는 패턴 매칭)
    local folders=()
    if [ -f ".ssafy_playlist" ]; then
        while IFS= read -r folder; do
            [ -d "$folder" ] && folders+=("$folder")
        done < ".ssafy_playlist"
    else
        for folder in */; do
            folder="${folder%/}"
            if [[ "$folder" =~ ^[A-Za-z0-9]+_(ws|hw|ex)_[0-9]+(_[0-9]+)?$ ]]; then
                folders+=("$folder")
            fi
        done
    fi
    
    if [ ${#folders[@]} -eq 0 ]; then
        echo "⚠️  처리할 폴더가 없습니다."
        return 0
    fi
    
    echo "📋 처리할 폴더: ${#folders[@]}개"
    echo ""
    
    local success_count=0
    local fail_count=0
    local skip_count=0
    local progress_file="$ssafy_root/.ssafy_progress"
    local pushed_folders=()
    
    for folder in "${folders[@]}"; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📁 [$folder]"
        
        cd "$ssafy_root/$folder" || {
            echo "  ❌ 폴더 이동 실패"
            ((fail_count++))
            continue
        }
        
        # 변경사항 확인
        if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
            echo "  ⏭️  변경사항 없음 (스킵)"
            ((skip_count++))
            cd "$ssafy_root"
            continue
        fi
        
        # Git 작업
        git add .
        if git commit -m "${GIT_COMMIT_PREFIX:-solve}: $folder" 2>/dev/null; then
            if git push 2>/dev/null; then
                echo "  ✅ 푸시 완료"
                ((success_count++))
                pushed_folders+=("$folder")
                # .ssafy_progress에 완료 기록
                echo "$folder=done" >> "$progress_file"
            else
                echo "  ❌ 푸시 실패"
                ((fail_count++))
            fi
        else
            echo "  ⚠️  커밋 실패 (이미 커밋됨?)"
            ((skip_count++))
        fi
        
        cd "$ssafy_root"
    done
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 결과: ✅ ${success_count} 성공 | ❌ ${fail_count} 실패 | ⏭️ ${skip_count} 스킵"
    
    # 미완료 폴더 확인 (동적 Playlist)
    _check_unsolved_folders "$ssafy_root" "${folders[@]}"
    
    # 제출 링크 일괄 출력 (Phase 3)
    if [ ${#pushed_folders[@]} -gt 0 ]; then
        _show_submission_links "$ssafy_root" "${pushed_folders[@]}"
    fi
}

# =============================================================================
# _sync_playlist_status - Git 로그 기반 완료 여부 동기화 (Auto-Sync)
# =============================================================================
_sync_playlist_status() {
    local ssafy_root="$1"
    local user_name=$(git config user.name)
    local prefix="${GIT_COMMIT_PREFIX:-solve}"
    local progress_file="$ssafy_root/.ssafy_progress"
    
    if [ -z "$user_name" ]; then return; fi
    
    # .ssafy_progress 없으면 생성
    if [ ! -f "$progress_file" ]; then touch "$progress_file"; fi
    
    local original_dir=$(pwd)
    cd "$ssafy_root" || return
    
    # 진행 상황 표시 (너무 빠르면 시각적 효과 없음, 적당히)
    # echo "🔄 기존 풀이 동기화 중..."
    
    # 1. 파일 이름 규칙으로 폴더 찾기
    for folder in *_ws_* *_hw_* *_ex_*; do
        if [ -d "$folder" ] && [ -d "$folder/.git" ]; then
            # 이미 기록된 경우 스킵
            if grep -q "^${folder}=done" "$progress_file" 2>/dev/null; then
                continue
            fi
            
            # 2. Git 로그 확인 (Author + Prefix)
            # 최근 20개 커밋 검사
            cd "$folder"
            if git log --author="$user_name" --oneline -n 20 2>/dev/null | grep -qE "[a-f0-9]+ ${prefix}:"; then
                 echo "${folder}=done" >> "$progress_file"
                 # echo "  ✅ [Auto-Sync] $folder 복구됨"
            fi
            cd ..
        fi
    done
    
    cd "$original_dir"
}

# =============================================================================
# _check_unsolved_folders - 미완료 폴더 감지
# =============================================================================
_check_unsolved_folders() {
    local ssafy_root="$1"
    shift
    local all_folders=("$@")
    local progress_file="$ssafy_root/.ssafy_progress"
    local unsolved=()
    
    for folder in "${all_folders[@]}"; do
        if ! grep -q "^${folder}=done" "$progress_file" 2>/dev/null; then
            unsolved+=("$folder")
        fi
    done
    
    if [ ${#unsolved[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  아직 완료되지 않은 문제가 있습니다:"
        local i=1
        for folder in "${unsolved[@]}"; do
            echo "  $i. $folder"
            ((i++))
        done
        echo ""
        echo "👉 번호 입력 시 해당 폴더로 이동 | Enter → 종료"
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#unsolved[@]} ]; then
            local selected="${unsolved[$((choice-1))]}"
            echo "➡️  $selected 로 이동합니다."
            _open_repo_file "$ssafy_root/$selected"
        fi
    else
        echo ""
        echo "🎉 모든 문제를 완료했습니다! 고생하셨습니다!"
    fi
}

# =============================================================================
# _show_submission_links - 제출 링크 출력
# =============================================================================
_show_submission_links() {
    local ssafy_root="$1"
    shift
    local folders=("$@")
    
    # 메타데이터 파일에서 course_id, practice_id 읽기
    local meta_file="$ssafy_root/.ssafy_session_meta"
    if [ ! -f "$meta_file" ]; then
        return 0
    fi
    
    local course_id=$(grep "^course_id=" "$meta_file" 2>/dev/null | cut -d= -f2)
    
    if [ -z "$course_id" ]; then
        return 0
    fi
    
    echo ""
    echo "📋 제출 링크 목록:"
    
    local i=1
    local has_link=false
    
    for folder in "${folders[@]}"; do
        # 폴더별 practice_id 조회 (folder=ID)
        local pr_id=$(grep "^$folder=" "$meta_file" 2>/dev/null | cut -d= -f2)
        
        # 하위 호환: practice_id=ID (단일)
        if [ -z "$pr_id" ]; then
            pr_id=$(grep "^practice_id=" "$meta_file" 2>/dev/null | cut -d= -f2)
        fi
        
        # 폴더별 pa_id 조회 (folder_pa=ID)
        local pa_id=$(grep "^${folder}_pa=" "$meta_file" 2>/dev/null | cut -d= -f2)
        
        if [ -n "$pr_id" ]; then
            local base_url=""
            if [ -n "$pa_id" ]; then
                 base_url="https://project.ssafy.com/practiceroom/course/${course_id}/practice/${pr_id}/answer/${pa_id}"
            else
                 # Fallback: 상세 페이지
                 base_url="https://project.ssafy.com/practiceroom/course/${course_id}/practice/${pr_id}/detail"
            fi
            echo "  $i. $folder: $base_url"
            has_link=true
        else
            echo "  $i. $folder: (링크 정보 없음)"
        fi
        ((i++))
    done
    
    if [ "$has_link" = false ]; then return 0; fi
    echo ""
    echo "👉 'a' → 전체 열기 | 번호 → 해당 링크 열기 | Enter → 종료"
    read -r choice
    
    if [ "$choice" = "a" ]; then
        _open_browser "$base_url"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#folders[@]} ]; then
        _open_browser "$base_url"
    fi
}

# =============================================================================
# _open_browser - 브라우저에서 URL 열기
# =============================================================================
_open_browser() {
    local url="$1"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || command -v powershell.exe > /dev/null 2>&1; then
        start "" "$url" 2>/dev/null || powershell.exe -Command "Start-Process '$url'" 2>/dev/null
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        open "$url"
    else
        xdg-open "$url" 2>/dev/null || echo "🔗 $url"
    fi
}

# =============================================================================
# gitdown - Git 작업 완료 자동화
# =============================================================================

gitdown() {
    init_algo_config
    
    # --all 플래그 체크 (먼저 처리)
    for arg in "$@"; do
        if [ "$arg" = "--all" ] || [ "$arg" = "-a" ] || [ "$arg" = "-all" ]; then
            _gitdown_all
            return $?
        fi
    done
    
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
                echo "⚠️  SSAFY 루트로 이동할 수 없습니다: $ssafy_root"
                return 1
            }
        fi
    fi

    if [ "$ssafy_mode" = true ]; then
        if [ "$push_ok" = true ]; then
            # [Playlist Sync] 개별 gitdown 성공 시에도 완료 처리
            if [ -n "$ssafy_root" ] && [ -f "$ssafy_root/.ssafy_progress" ]; then
                 if ! grep -q "^${current_repo}=done" "$ssafy_root/.ssafy_progress" 2>/dev/null; then
                     echo "${current_repo}=done" >> "$ssafy_root/.ssafy_progress"
                 fi
            fi

            # 제출 링크 출력
            _show_submission_links "$(pwd)" "$current_repo"
            
            local next_repo=$(_ssafy_next_repo "$current_repo")
            if [ -n "$next_repo" ] && [ ! -d "$next_repo" ]; then
                echo "⚠️  다음 문제 레포가 로컬에 없습니다: $next_repo"
                echo "💡  SSAFY에서 실습실/과제를 생성해야 레포가 만들어질 수 있습니다."
            fi
            if [ -n "$next_repo" ] && [ -d "$next_repo" ]; then
                echo "➡️  다음 문제로 이동: $next_repo"
                _open_repo_file "$next_repo" || echo "⚠️  다음 디렉터리로 이동할 수 없습니다: $next_repo"
            else
                # [Dynamic Playlist Fallback]
                # Git 로그 기반으로 기존 완료 내역 동기화 (Auto-Sync)
                _sync_playlist_status "$ssafy_root"
                
                # 다음 번호의 문제가 없더라도, 다른 안 푼 문제가 있는지 확인
                local all_folders=()
                local playlist_file="$ssafy_root/.ssafy_playlist"
                local meta_file="$ssafy_root/.ssafy_session_meta"
                
                if [ -f "$playlist_file" ]; then
                    # Playlist 파일 사용
                    while IFS= read -r line || [ -n "$line" ]; do
                        all_folders+=("$line")
                    done < "$playlist_file"
                elif [ -f "$meta_file" ]; then
                    # Meta 파일에서 폴더 추출 (키 제외)
                    # course_id=..., practice_id=... 제외, _pa=... 패턴은 별도 라인이므로 폴더명 아님
                    # 하지만 folder_pa=PA... 형식이므로 cut -d_ -f1하면 folder가 나옴.
                    # 가장 확실한 건 folder=ID 라인임.
                    while IFS= read -r line || [ -n "$line" ]; do
                        if [[ "$line" =~ ^([^=]+)=([^=]+)$ ]]; then
                            local key="${BASH_REMATCH[1]}"
                            # key가 예약어가 아니고 _pa로 끝나지 않으면 폴더명으로 간주
                            if [[ "$key" != "course_id" ]] && [[ "$key" != "practice_id" ]] && [[ "$key" != *"_pa" ]]; then
                                all_folders+=("$key")
                            fi
                        fi
                    done < "$meta_file"
                fi
                
                # 그래도 비어있으면 현재 디렉토리 스캔
                if [ ${#all_folders[@]} -eq 0 ]; then
                    for d in *_ws_* *_hw_* *_ex_*; do
                        [ -d "$d" ] && all_folders+=("$d")
                    done
                fi

                if [ ${#all_folders[@]} -gt 0 ]; then
                    _check_unsolved_folders "$ssafy_root" "${all_folders[@]}"
                else
                    # 기존 종료 메시지 (폴더 목록을 못 구한 경우)
                    if [[ "$current_repo" =~ ^([A-Za-z0-9]+)_(ws|hw|ex)_([0-9]+)(_[0-9]+)?$ ]]; then
                        local topic="${BASH_REMATCH[1]}"
                        local session="${BASH_REMATCH[3]}"
                        echo ""
                        echo "🎉 [${topic}] 과목의 해당 [${session}]차시가 종료되었습니다. 고생하셨습니다"
                    else
                        echo "⚠️  다음 문제를 찾을 수 없습니다."
                    fi
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

_gitup_ssafy() {
    local input="$1"

    _ensure_ssafy_config
    if [ -z "${SSAFY_BASE_URL:-}" ] || [ -z "${SSAFY_USER_ID:-}" ]; then
        echo "⚠️  SSAFY 설정이 필요합니다. 'algo-config edit'로 SSAFY_BASE_URL/SSAFY_USER_ID를 설정하세요."
        return 1
    fi
    # ... (rest of _gitup_ssafy implementation) ... (This is too large to replace in one go efficiently if not changing. I will use multi_replace for accuracy)
    local input="$1"

    _ensure_ssafy_config
    if [ -z "${SSAFY_BASE_URL:-}" ] || [ -z "${SSAFY_USER_ID:-}" ]; then
        echo "⚠️  SSAFY 설정이 필요합니다. 'algo-config edit'로 SSAFY_BASE_URL/SSAFY_USER_ID를 설정하세요."
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

    if [[ "$repo_name" =~ ^([A-Za-z0-9]+)_(ws|hw|ex)_([0-9]+)_[0-9]+$ ]]; then
        topic="${BASH_REMATCH[1]}"
        session="${BASH_REMATCH[3]}"
    elif [[ "$repo_name" =~ ^([A-Za-z0-9]+)_(ws|hw|ex)_([0-9]+)$ ]]; then
        topic="${BASH_REMATCH[1]}"
        session="${BASH_REMATCH[3]}"
    elif [[ "$repo_name" =~ ^([A-Za-z0-9]+)_(ws|hw|ex)$ ]]; then
        topic="${BASH_REMATCH[1]}"
        read -r -p "차시 입력: " session
    elif [[ "$repo_name" =~ ^([A-Za-z0-9]+)$ ]]; then
        topic="$repo_name"
        read -r -p "차시 입력: " session
    else
        if [[ "$repo_name" =~ ^(ws|hw|ex)_[0-9]+(_[0-9]+)?$ ]]; then
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

    if ! [[ "$repo_name" =~ ^([A-Za-z0-9]+)_(ws|hw|ex)_([0-9]+)_([0-9]+)$ ]]; then
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
                # [V7.0 Smart Copy] URL|Token 분리 처리
                if [[ "$1" == *"|"* ]]; then
                    local raw="$1"
                    local url="${raw%%|*}"
                    local token="${raw#*|}"
                    
                    if [ -z "$input" ]; then
                        input="$url"
                    fi
                    
                    # 토큰 업데이트 (Base64 Encoded 상태 그대로 저장)
                    if [ -n "$token" ]; then
                        if [ -f "$ALGO_CONFIG_FILE" ]; then
                            local safe_token=$(echo "$token" | sed 's/[\/&]/\\&/g')
                            if sed --version >/dev/null 2>&1; then
                                sed -i "s|^SSAFY_AUTH_TOKEN=.*|SSAFY_AUTH_TOKEN=\"$safe_token\"|" "$ALGO_CONFIG_FILE"
                            else
                                sed -i '' "s|^SSAFY_AUTH_TOKEN=.*|SSAFY_AUTH_TOKEN=\"$safe_token\"|" "$ALGO_CONFIG_FILE"
                            fi
                            # 메모리 로드 (디코딩)
                            local decoded=$(echo "$token" | base64 -d 2>/dev/null || echo "")
                            if [[ "$decoded" == "Bearer "* ]]; then
                                export SSAFY_AUTH_TOKEN="$decoded"
                                echo "🔐 [Smart Copy] 인증 토큰 자동 업데이트 완료"
                            fi
                        fi
                    fi
                elif [ -z "$input" ]; then
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
        
        # 스크립트 위치 동적 감지
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        
        local first_dir=""
        local priority_dir=""
        
        # .ssafy_playlist 초기화
        rm -f .ssafy_playlist
        
        # 파이썬 스크립트 실행 및 결과 파싱
        # 출력형식: URL|CourseID|PracticeID|PA_ID
        python "$script_dir/ssafy_batch_create.py" "$input" 20 --pipe 2>/dev/null | while IFS='|' read -r url course_id pr_id pa_id; do
            # Windows 호환: \r 제거 (필수)
            url=$(echo "$url" | tr -d '\r')
            course_id=$(echo "$course_id" | tr -d '\r')
            pr_id=$(echo "$pr_id" | tr -d '\r')
            pa_id=$(echo "$pa_id" | tr -d '\r')
            
            if [ -n "$url" ]; then
                local repo_name=$(basename "$url" .git)
                echo "⬇️  Clone: $repo_name"
                
                # git clone 실행
                git clone "$url" 2>/dev/null
                
                # 플레이리스트 추가
                echo "$repo_name" >> .ssafy_playlist
                
                # 메타데이터 저장
                # 1. course_id (없으면 저장)
                if [ -n "$course_id" ] && ! grep -q "^course_id=" .ssafy_session_meta 2>/dev/null; then
                    echo "course_id=$course_id" >> .ssafy_session_meta
                fi
                
                # 2. practice_id (폴더별 매핑 저장: folder=pr_id)
                if [ -n "$pr_id" ]; then
                    if ! grep -q "^$repo_name=" .ssafy_session_meta 2>/dev/null; then
                        echo "$repo_name=$pr_id" >> .ssafy_session_meta
                    fi
                fi
                
                # 3. pa_id (폴더별 매핑 저장: folder_pa=pa_id)
                if [ -n "$pa_id" ]; then
                    if ! grep -q "^${repo_name}_pa=" .ssafy_session_meta 2>/dev/null; then
                         echo "${repo_name}_pa=$pa_id" >> .ssafy_session_meta
                    fi
                fi
            fi
        done
        
        echo "✅ 일괄 작업 완료!"
        echo "📋 자동 이동 순서 생성됨 (.ssafy_playlist)"
        
        # playlist 파일에서 첫 번째 항목 읽기 (Subshell 문제 회피)
        if [ -f ".ssafy_playlist" ]; then
             local top_dir=$(head -n 1 .ssafy_playlist)
             first_dir="$top_dir"
             
             # 우선순위(_1) 찾기 - grep 결과가 여러 줄일 수 있으니 head -n 1
             priority_dir=$(grep "_1$" .ssafy_playlist 2>/dev/null | head -n 1)
        fi
        
        if [ -n "$priority_dir" ]; then
            first_dir="$priority_dir"
        fi
        
        if [ -n "$first_dir" ] && [ -d "$first_dir" ]; then
            echo "👉 첫 번째 문제로 이동합니다: $first_dir"
            _open_repo_file "$first_dir"
            return 0
        else
            if [ -f ".ssafy_playlist" ]; then
                echo "⚠️  클론은 완료되었으나 폴더 이동에 실패했습니다."
                echo "    (직접 폴더로 이동해주세요: $(head -n 1 .ssafy_playlist))"
            else
                echo "⚠️  클론된 디렉토리를 찾을 수 없습니다."
            fi
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

# ===================================================
# get_ide - 설정된 IDE 반환
# ===================================================
get_ide() {
    init_algo_config
    
    # IDE_EDITOR가 설정되어 있으면 사용
    if [ -n "${IDE_EDITOR:-}" ]; then
        echo "$IDE_EDITOR"
        return
    fi
    
    # 하위 호환: IDE_PRIORITY가 있으면 첫 번째 값 사용
    if [ -n "${IDE_PRIORITY:-}" ]; then
        local first_ide
        first_ide=$(echo "$IDE_PRIORITY" | awk '{print $1}')
        echo "$first_ide"
        return
    fi
    
    # 기본값
    echo "code"
}

# 하위 호환성을 위한 별칭
get_active_ide() {
    get_ide
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
        echo "📌 감지된 IDE: $editor"
        echo "🎉 에디터에서 파일 열기: $chosen"
        _open_in_editor "$editor" "$chosen"
    else
        echo "⚠️  열 파일을 찾을 수 없습니다"
        echo "📋 클론된 폴더 내용:"
        ls -la
    fi

    echo "✅ 프로젝트 준비 완료!"
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

# =============================================================================
# algo-doctor - 시스템 및 설정 진단 도구 (V7.0)
# =============================================================================
algo-doctor() {
    echo "=================================================="
    echo " ��� SSAFY Algo Tools Doctor (V${ALGO_FUNCTIONS_VERSION})"
    echo "=================================================="
    echo ""
    
    local issues=0
    
    # [1] 필수 도구 점검
    echo "1️⃣  필수 도구 점검"
    for tool in git python3 curl base64; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "   ✅ $tool: 설치됨 ($(command -v "$tool"))"
        else
            echo "   ❌ $tool: 설치되지 않음!"
            ((issues++))
        fi
    done
    
    # [2] 설정 파일 보안 점검
    echo ""
    echo "2️⃣  설정 파일 보안 점검"
    if [ -f "$ALGO_CONFIG_FILE" ]; then
        if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "win32" ]]; then
            local perms=$(stat -c "%a" "$ALGO_CONFIG_FILE" 2>/dev/null || echo "unknown")
            if [ "$perms" == "600" ]; then
                echo "   ✅ 권한: 600 (안전함)"
            else
                echo "   ⚠️  권한: $perms (권장: 600)"
                # issues++ (윈도우 이슈로 경고만)
            fi
        else
             echo "   ℹ️  Windows/Git Bash 환경 (권한 체크 생략)"
        fi
        
        # 토큰 암호화 여부 체크
        # grep으로 파일 내용 직접 확인
        local file_token=$(grep "SSAFY_AUTH_TOKEN" "$ALGO_CONFIG_FILE" | cut -d= -f2 | tr -d '"')
        if [[ "$file_token" == "Bearer "* ]]; then
            echo "   ⚠️  토큰 저장 상태: 평문 (보안 취약)"
            echo "      -> 'source ~/.bashrc'를 다시 실행하면 암호화됩니다."
            ((issues++))
        elif [ -n "$file_token" ]; then
            echo "   ✅ 토큰 저장 상태: 암호화됨 (Base64)"
        else
            echo "   ℹ️  토큰 미설정"
        fi
    else
        echo "   ❌ 설정 파일 없음 (\ (~/algo_config))"
        ((issues++))
    fi
    
    # [3] IDE 설정 점검
    echo ""
    echo "3️⃣  IDE 설정 점검"
    if [ -n "$IDE_EDITOR" ]; then
        if command -v "$IDE_EDITOR" >/dev/null 2>&1; then
            echo "   ✅ IDE: $IDE_EDITOR (실행 가능)"
        else
             # Windows의 경우 .exe가 빠져있을 수 있으므로 체크
             if command -v "${IDE_EDITOR}.exe" >/dev/null 2>&1; then
                 echo "   ✅ IDE: $IDE_EDITOR.exe (실행 가능)"
             else
                 echo "   ❌ IDE: $IDE_EDITOR (명령어를 찾을 수 없음)"
                 echo "      -> PATH에 추가하거나 algo-config에서 올바른 명령어로 변경하세요."
                 ((issues++))
             fi
        fi
    else
        echo "   ⚠️  IDE 미설정"
    fi
    
    # [4] SSAFY 서버 연결 (토큰 유효성)
    echo ""
    echo "4️⃣  SSAFY 서버 연결"
    if [ -n "$SSAFY_AUTH_TOKEN" ] && [[ "$SSAFY_AUTH_TOKEN" == "Bearer "* ]]; then
        # 간단한 curl 호출 (헤더만)
        # 401이면 토큰 만료, 200/404 등은 연결 성공
        local status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: $SSAFY_AUTH_TOKEN" "${SSAFY_BASE_URL:-https://lab.ssafy.com}/api/v4/user" || echo "fail")
        
        if [ "$status_code" == "200" ]; then
            echo "   ✅ 인증 상태: 유효함 (연결 성공)"
        elif [ "$status_code" == "401" ]; then
             echo "   ❌ 인증 상태: 토큰 만료 또는 잘못됨 (401)"
             ((issues++))
        elif [ "$status_code" == "fail" ]; then
             echo "   ⚠️  서버 연결 실패 (네트워크 확인)"
        else
             echo "   ✅ 서버 응답: $status_code (연결됨)"
        fi
    else
        echo "   ℹ️  토큰이 없어 연결 테스트를 건너뜁니다."
    fi
    
    echo ""
    echo "=================================================="
    if [ $issues -eq 0 ]; then
        echo "���  모든 시스템이 정상입니다!"
    else
        echo "⚠️  $issues 건의 문제점이 발견되었습니다."
    fi
    echo "=================================================="
}
