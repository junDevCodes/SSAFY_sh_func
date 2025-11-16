#!/bin/bash

# =============================================================================
# 알고리즘 문제 풀이 자동화 셸 함수 (공개용)
# =============================================================================

# 설정 파일 경로
ALGO_CONFIG_FILE="$HOME/.algo_config"

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
EOF
        echo "✅ 설정 파일 생성: $ALGO_CONFIG_FILE"
        echo "💡 'algo-config' 명령어로 설정을 변경할 수 있습니다"
    fi
    source "$ALGO_CONFIG_FILE"
}

# 설정 편집 명령어
algo-config() {
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

# =============================================================================
# al - 알고리즘 문제 환경 설정
# =============================================================================
al() {
    init_algo_config
    
    # 인자 검증
    if [ $# -eq 0 ]; then
        echo "❗️사용법: al <사이트> <문제번호> [옵션]"
        echo ""
        echo "📋 지원 사이트:"
        echo "  s  → SWEA (Samsung SW Expert Academy)"
        echo "  b  → BOJ (Baekjoon Online Judge)"
        echo "  p  → Programmers"
        echo ""
        echo "⚙️  옵션:"
        echo "  --no-git    Git 커밋/푸시 건너뛰기"
        echo "  --no-open   파일 열기 건너뛰기"
        echo ""
        echo "💡 사용 예제:"
        echo "  al s 1234          # SWEA 1234번 문제"
        echo "  al b 10950         # BOJ 10950번 문제"
        echo "  al p 42576         # 프로그래머스 42576번 문제"
        echo "  al b 1000 --no-git # Git 작업 없이 파일만 생성"
        return 1
    fi
    
    local site_code="$1"
    local problem="$2"
    local skip_git=false
    local skip_open=false
    
    # 옵션 파싱
    shift 2
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-git) skip_git=true ;;
            --no-open) skip_open=true ;;
        esac
        shift
    done
    
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
    local file="$dir/${file_prefix}_${problem}.py"
    
    echo "🎯 사이트: $site_display"
    echo "📝 문제번호: $problem"
    echo "📁 경로: $dir"
    
    # 디렉토리 생성
    mkdir -p "$dir"
    
    # 파일 생성 또는 Git 작업
    if [ ! -f "$file" ]; then
        _create_algo_file "$file" "$site_name" "$site_display" "$problem"
    else
        echo "📄 기존 파일 발견!"
        if [ "$skip_git" = false ]; then
            _handle_git_commit "$dir" "$file_prefix" "$problem"
        else
            echo "⏭️  Git 작업 건너뛰기"
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
    
    echo "🆕 새 문제 파일 생성 중..."
    
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

# Git 커밋 처리 내부 함수
_handle_git_commit() {
    local dir="$1"
    local file_prefix="$2"
    local problem="$3"
    
    # 원래 디렉토리 저장
    local original_dir=$(pwd)
    
    # Git 저장소 찾기
    local git_root=""
    local current_dir="$dir"
    
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
    
    local relative_path=$(realpath --relative-to="$git_root" "$dir" 2>/dev/null || \
        python3 -c "import os.path; print(os.path.relpath('$dir', '$git_root'))")
    
    echo "✅ Git 저장소: $git_root"
    echo "📁 대상: $relative_path"
    
    git add "$relative_path"
    
    local commit_msg="${GIT_COMMIT_PREFIX}: ${file_prefix}_${problem}"
    
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
    
    # 커밋 메시지 생성
    if [ -n "$1" ]; then
        commit_msg="$1"
    else
        local py_file=$(find . -maxdepth 1 -name "*.py" -type f | head -n 1)
        if [ -n "$py_file" ]; then
            local filename=$(basename "$py_file" .py)
            commit_msg="${GIT_COMMIT_PREFIX}: $filename"
        else
            # 현재 디렉토리명 추출 (Windows 경로도 처리)
            local current_dir="${PWD:-$(pwd)}"
            local folder_name=$(basename "$current_dir" 2>/dev/null || echo "unknown")
            
            # 빈 문자열이나 특수 케이스 처리
            if [ -z "$folder_name" ] || [ "$folder_name" = "/" ] || [ "$folder_name" = "\\" ]; then
                folder_name="root"
            fi
            
            echo "📂 현재 폴더: $folder_name"
            commit_msg="${GIT_COMMIT_PREFIX}: $folder_name"
        fi
    fi
    
    echo "📝 모든 변경사항을 추가하고 커밋합니다..."
    git add .
    
    echo "📌 커밋 메시지: $commit_msg"
    if git commit -m "$commit_msg"; then
        echo "✅ 커밋 완료"
        
        if [ "$GIT_AUTO_PUSH" = true ]; then
            echo "🌐 원격 저장소로 푸시 중..."
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
        echo "⚠️  커밋 실패"
        return 1
    fi
    
    echo "📁 상위 폴더로 이동"
    cd .. || {
        echo "⚠️  상위 폴더로 이동할 수 없습니다"
        return 1
    }
}

# =============================================================================
# gitup - Git 저장소 클론 및 시작
# =============================================================================
gitup() {
    if [ -z "$1" ]; then
        echo "❗️사용법: gitup <git-repository-url>"
        echo "예시: gitup https://github.com/user/repo.git"
        return 1
    fi
    
    echo "🔄 Git 저장소 클론 중: $1"
    git clone "$1" || return 1
    
    local repo_name=$(basename "$1" .git)
    echo "📂 $repo_name 폴더로 이동"
    cd "$repo_name" || return
    
    # 우선순위에 따라 파일 찾기
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
    algo-config show | grep "IDE_PRIORITY" || echo "   설정 파일을 찾을 수 없습니다"
    
    echo ""
    echo "💡 IDE 우선순위를 변경하려면: algo-config edit"
}

# =============================================================================
# 초기화 실행
# =============================================================================
init_algo_config

echo "✅ 알고리즘 셸 함수 로드 완료!"
echo "💡 'algo-config edit'로 설정을 변경할 수 있습니다"