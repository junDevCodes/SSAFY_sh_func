# =============================================================================
# lib/templates.sh
# Algorithm File Templates & Generation (V7.6)
# =============================================================================

# =============================================================================
# al - 알고리즘 문제 환경 설정 (V7.6 네임스페이스)
# =============================================================================
ssafy_al() {
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
