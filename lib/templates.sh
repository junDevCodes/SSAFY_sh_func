# =============================================================================
# lib/templates.sh
# Algorithm file templates & generation
# =============================================================================

_ssafy_al_print_usage() {
    cat <<'EOF'
Usage: al <site> <problem> [py|cpp] [options]

Sites:
  s  -> SWEA (Samsung SW Expert Academy)
  b  -> BOJ (Baekjoon Online Judge)
  p  -> Programmers

Languages:
  py   -> Python (default)
  cpp  -> C++

Options:
  --no-git         Skip git commit/push flow
  --no-open        Skip opening file in IDE
  --msg, -m <msg>  Commit message

Examples:
  al s 1234
  al b 10950
  al p 42576
  al b 1000 --no-git
  al b 1000 --msg "fix: typo"
  al b 1000 cpp
EOF
}

_ssafy_al_resolve_site() {
    local site_code="$1"
    case "$site_code" in
        s|swea)
            SSAFY_AL_SITE_NAME="swea"
            SSAFY_AL_FILE_PREFIX="swea"
            SSAFY_AL_SITE_DISPLAY="SWEA"
            return 0
            ;;
        b|boj)
            SSAFY_AL_SITE_NAME="boj"
            SSAFY_AL_FILE_PREFIX="boj"
            SSAFY_AL_SITE_DISPLAY="BOJ"
            return 0
            ;;
        p|programmers)
            SSAFY_AL_SITE_NAME="programmers"
            SSAFY_AL_FILE_PREFIX="programmers"
            SSAFY_AL_SITE_DISPLAY="Programmers"
            return 0
            ;;
    esac
    return 1
}

_ssafy_al_interactive_flow() {
    local site_code="${1:-b}"
    local problem="${2:-}"
    local lang="${3:-py}"
    local skip_git="${4:-false}"
    local skip_open="${5:-false}"
    local custom_commit_msg="${6:-}"
    local answer=""
    local rc=0
    local step=1

    if ! type input_choice >/dev/null 2>&1; then
        return 1
    fi

    if [ -z "$site_code" ] || ! _ssafy_al_resolve_site "$site_code"; then
        site_code="b"
    fi
    if [ "$lang" != "py" ] && [ "$lang" != "cpp" ]; then
        lang="py"
    fi

    while true; do
        case "$step" in
            1)
                input_choice site_code "Step 1/7: Select site" "$site_code" \
                    "s:SWEA" "b:BOJ" "p:Programmers"
                rc=$?
                case "$rc" in
                    0) step=2 ;;
                    20) return 20 ;;
                esac
                ;;
            2)
                input_text problem "Step 2/7: Enter problem number" "$problem"
                rc=$?
                case "$rc" in
                    0)
                        if [[ "$problem" =~ ^[0-9]+$ ]]; then
                            step=3
                        else
                            if type ui_warn >/dev/null 2>&1; then
                                ui_warn "Problem number must be numeric."
                            else
                                echo "[WARN] Problem number must be numeric."
                            fi
                        fi
                        ;;
                    10) step=1 ;;
                    20) return 20 ;;
                esac
                ;;
            3)
                input_choice lang "Step 3/7: Select language" "$lang" \
                    "py:Python" "cpp:C++"
                rc=$?
                case "$rc" in
                    0) step=4 ;;
                    10) step=2 ;;
                    20) return 20 ;;
                esac
                ;;
            4)
                if [ "$skip_git" = "true" ]; then
                    answer="yes"
                else
                    answer="no"
                fi
                input_confirm answer "Step 4/7: Skip git stage?" "$([ "$answer" = "yes" ] && echo y || echo n)"
                rc=$?
                case "$rc" in
                    0)
                        if [ "$answer" = "yes" ]; then
                            skip_git=true
                        else
                            skip_git=false
                        fi
                        step=5
                        ;;
                    10) step=3 ;;
                    20) return 20 ;;
                esac
                ;;
            5)
                if [ "$skip_open" = "true" ]; then
                    answer="yes"
                else
                    answer="no"
                fi
                input_confirm answer "Step 5/7: Skip open editor stage?" "$([ "$answer" = "yes" ] && echo y || echo n)"
                rc=$?
                case "$rc" in
                    0)
                        if [ "$answer" = "yes" ]; then
                            skip_open=true
                        else
                            skip_open=false
                        fi
                        step=6
                        ;;
                    10) step=4 ;;
                    20) return 20 ;;
                esac
                ;;
            6)
                input_text custom_commit_msg "Step 6/7: Commit message (blank for auto)" "$custom_commit_msg" true
                rc=$?
                case "$rc" in
                    0)
                        if [ -n "$custom_commit_msg" ] && [ -z "${custom_commit_msg//[[:space:]]/}" ]; then
                            if type ui_warn >/dev/null 2>&1; then
                                ui_warn "Commit message cannot be whitespace only."
                            else
                                echo "[WARN] Commit message cannot be whitespace only."
                            fi
                        else
                            step=7
                        fi
                        ;;
                    10) step=5 ;;
                    20) return 20 ;;
                esac
                ;;
            7)
                if type ui_panel_begin >/dev/null 2>&1; then
                    ui_panel_begin "al" "실행 전 미리보기"
                    ui_info "site=$site_code"
                    ui_info "problem=$problem"
                    ui_info "language=$lang"
                    ui_info "skip_git=$skip_git"
                    ui_info "skip_open=$skip_open"
                    if [ -n "$custom_commit_msg" ]; then
                        ui_info "commit_msg=$custom_commit_msg"
                    else
                        ui_info "commit_msg=(auto)"
                    fi
                    ui_panel_end
                else
                    echo "[INFO] site=$site_code"
                    echo "[INFO] problem=$problem"
                    echo "[INFO] language=$lang"
                fi
                input_confirm answer "Step 7/7: Run now?" "y"
                rc=$?
                case "$rc" in
                    0)
                        if [ "$answer" = "yes" ]; then
                            break
                        fi
                        return 20
                        ;;
                    10) step=6 ;;
                    20) return 20 ;;
                esac
                ;;
        esac
    done

    SSAFY_AL_FLOW_SITE="$site_code"
    SSAFY_AL_FLOW_PROBLEM="$problem"
    SSAFY_AL_FLOW_LANG="$lang"
    SSAFY_AL_FLOW_SKIP_GIT="$skip_git"
    SSAFY_AL_FLOW_SKIP_OPEN="$skip_open"
    SSAFY_AL_FLOW_COMMIT_MSG="$custom_commit_msg"
    return 0
}

ssafy_al() {
    init_algo_config

    local site_code="${1:-}"
    local problem="${2:-}"
    local lang="py"
    local lang_provided=false
    local skip_git=false
    local skip_open=false
    local custom_commit_msg=""
    local parse_error=""
    local run_interactive=false

    if [ $# -ge 2 ]; then
        shift 2
        while [ $# -gt 0 ]; do
            case "$1" in
                py|cpp)
                    if [ "$lang_provided" = false ]; then
                        lang="$1"
                        lang_provided=true
                    else
                        parse_error="Only one language can be selected."
                        break
                    fi
                    ;;
                --no-git) skip_git=true ;;
                --no-open) skip_open=true ;;
                --msg|-m)
                    shift
                    if [ -z "${1:-}" ] || [[ "$1" == --* ]]; then
                        parse_error="--msg requires a commit message."
                        break
                    fi
                    custom_commit_msg="$1"
                    ;;
                --msg=*)
                    custom_commit_msg="${1#--msg=}"
                    if [ -z "$custom_commit_msg" ]; then
                        parse_error="--msg requires a commit message."
                        break
                    fi
                    ;;
                --*)
                    parse_error="Unknown option: $1"
                    break
                    ;;
                *)
                    if [ -z "$custom_commit_msg" ]; then
                        custom_commit_msg="$1"
                    else
                        parse_error="Commit message with spaces must be quoted."
                        break
                    fi
                    ;;
            esac
            shift
        done
    else
        parse_error="Missing required arguments."
    fi

    if [ -n "$custom_commit_msg" ] && [ -z "${custom_commit_msg//[[:space:]]/}" ]; then
        parse_error="Commit message cannot be empty."
    fi

    if [ -n "$site_code" ] && ! _ssafy_al_resolve_site "$site_code"; then
        parse_error="Invalid site code: $site_code"
    fi

    if [ -n "$problem" ] && ! [[ "$problem" =~ ^[0-9]+$ ]]; then
        parse_error="Problem number must be numeric: $problem"
    fi

    if [ -n "$parse_error" ]; then
        if _is_interactive; then
            run_interactive=true
        fi
    fi

    if [ "$run_interactive" = true ]; then
        _ssafy_al_interactive_flow "$site_code" "$problem" "$lang" "$skip_git" "$skip_open" "$custom_commit_msg"
        case $? in
            0)
                site_code="$SSAFY_AL_FLOW_SITE"
                problem="$SSAFY_AL_FLOW_PROBLEM"
                lang="$SSAFY_AL_FLOW_LANG"
                lang_provided=true
                skip_git="$SSAFY_AL_FLOW_SKIP_GIT"
                skip_open="$SSAFY_AL_FLOW_SKIP_OPEN"
                custom_commit_msg="$SSAFY_AL_FLOW_COMMIT_MSG"
                ;;
            20)
                if type ui_warn >/dev/null 2>&1; then
                    ui_warn "Canceled by user."
                else
                    echo "[WARN] Canceled by user."
                fi
                return 1
                ;;
            *)
                _ssafy_al_print_usage
                return 1
                ;;
        esac
    elif [ -n "$parse_error" ]; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "$parse_error"
        else
            echo "[ERROR] $parse_error"
        fi
        _ssafy_al_print_usage
        return 1
    fi

    if ! _ssafy_al_resolve_site "$site_code"; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "Invalid site code: $site_code"
        else
            echo "[ERROR] Invalid site code: $site_code"
        fi
        return 1
    fi

    local site_name="$SSAFY_AL_SITE_NAME"
    local file_prefix="$SSAFY_AL_FILE_PREFIX"
    local site_display="$SSAFY_AL_SITE_DISPLAY"

    if ! [[ "$problem" =~ ^[0-9]+$ ]]; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "Problem number must be numeric: $problem"
        else
            echo "[ERROR] Problem number must be numeric: $problem"
        fi
        return 1
    fi

    local dir="$ALGO_BASE_DIR/$site_name/$problem"
    local py_file="$dir/${file_prefix}_${problem}.py"
    local cpp_file="$dir/${file_prefix}_${problem}.cpp"
    local file=""

    if type ui_panel_begin >/dev/null 2>&1; then
        ui_panel_begin "al" "문제 파일 생성 + 선택 흐름 실행"
        ui_info "사이트=$site_display"
        ui_info "문제번호=$problem"
        ui_info "언어=${lang}"
        ui_path "$dir"
    else
        echo "[INFO] site=$site_display"
        echo "[INFO] problem=$problem"
        echo "[PATH] $dir"
    fi

    mkdir -p "$dir"

    local has_py=false
    local has_cpp=false
    [ -f "$py_file" ] && has_py=true
    [ -f "$cpp_file" ] && has_cpp=true

    if [ "$lang_provided" = true ]; then
        if [ "$lang" = "cpp" ]; then
            file="$cpp_file"
        else
            file="$py_file"
        fi

        if [ ! -f "$file" ]; then
            _create_algo_file "$file" "$site_name" "$site_display" "$problem" "$lang"
        else
            if type ui_warn >/dev/null 2>&1; then
                ui_warn "대상 파일이 이미 존재합니다."
            else
                echo "[WARN] Target file already exists."
            fi
            if [ "$skip_git" = false ]; then
                _handle_git_commit "$file" "$problem" "$custom_commit_msg" "$lang"
            else
                if type ui_info >/dev/null 2>&1; then
                    ui_info "Git 단계 건너뜀"
                else
                    echo "[INFO] Skip git stage."
                fi
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
                if type ui_info >/dev/null 2>&1; then
                    ui_info "Git 단계 건너뜀"
                else
                    echo "[INFO] Skip git stage."
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

    if [ "$skip_open" = false ]; then
        local editor
        editor=$(get_active_ide)
        if type ui_step >/dev/null 2>&1; then
            ui_step "에디터 열기: $editor"
        else
            echo "[STEP] Open file in editor: $editor"
        fi

        if [[ "$editor" == "code" || "$editor" == "cursor" ]]; then
            "$editor" -g "$file"
        else
            "$editor" "$file" &
        fi
    else
        if type ui_info >/dev/null 2>&1; then
            ui_info "파일 열기 단계 건너뜀"
        else
            echo "[INFO] Skip open stage."
        fi
    fi

    if type ui_ok >/dev/null 2>&1; then
        ui_ok "al 작업 완료"
        if type ui_panel_end >/dev/null 2>&1; then
            ui_panel_end
        fi
    else
        echo "[OK] al completed."
    fi
}

_create_algo_file() {
    local file="$1"
    local site_name="$2"
    local site_display="$3"
    local problem="$4"
    local lang="$5"

    if type ui_step >/dev/null 2>&1; then
        ui_step "템플릿 파일 생성: $file"
    else
        echo "[STEP] Create template file: $file"
    fi

    local sample_file
    sample_file="$(dirname "$file")/sample_input.txt"
    if [ ! -f "$sample_file" ]; then
        : > "$sample_file"
    fi

    if [ "$lang" = "cpp" ]; then
        : > "$file"
        if type ui_ok >/dev/null 2>&1; then
            ui_ok "C++ 파일 생성 완료"
        else
            echo "[OK] C++ file created."
        fi
        return 0
    fi

    cat > "$file" <<PYCODE
# $site_display $problem problem
import sys
from pathlib import Path

# Local input for offline tests
BASE_DIR = Path(__file__).resolve().parent
sys.stdin = (BASE_DIR / 'sample_input.txt').open('r', encoding='utf-8')

"""
[Problem]


[Constraints]


[Input]


[Output]


[Approach]
1.
2.
3.

[Complexity]
- Time: O()
- Space: O()
"""

PYCODE

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

# print(result)
BOJ_CODE
            ;;
        programmers)
            cat >> "$file" <<'PROG_CODE'
def solution(param):
    return param


if __name__ == "__main__":
    test_cases = [
        # (input, expected)
    ]

    for i, (inp, expected) in enumerate(test_cases):
        result = solution(inp)
        print(f"Test {i + 1}: {'OK' if result == expected else 'FAIL'}")
PROG_CODE
            ;;
    esac

    if type ui_ok >/dev/null 2>&1; then
        ui_ok "Python 파일 생성 완료"
    else
        echo "[OK] Python file created."
    fi
}
