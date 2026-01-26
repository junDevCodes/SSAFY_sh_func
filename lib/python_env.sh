# =============================================================================
# lib/python_env.sh
# Python Runtime Resolution (V8.0 Lazy Architecture)
# =============================================================================

# [V8.0 Architecture] Lazy Python Resolution (지연된 런타임 확정)
# 쉘 시작 시점에는 탐색하지 않고, 실제 명령이 실행될 때 탐색하여 캐싱함
_SSAFY_PYTHON_CACHE=""

_ssafy_python_lookup() {
    # 1. 이미 캐시된 값이 있으면 바로 반환
    if [ -n "$_SSAFY_PYTHON_CACHE" ]; then
        echo "$_SSAFY_PYTHON_CACHE"
        return 0
    fi

    # 2. 우선순위대로 탐색
    # V7.8: install.sh에서 설정한 SSAFY_PYTHON 환경변수를 최우선 사용
    if [ -n "${SSAFY_PYTHON:-}" ]; then
        export _SSAFY_PYTHON_CACHE="$SSAFY_PYTHON"
        echo "$SSAFY_PYTHON"
        return 0
    fi

    local candidates=("python3" "python" "py")
    local found=""

    for cmd in "${candidates[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            # Windows Store Shim 방지 (실행 검증)
            if "$cmd" -c "exit(0)" >/dev/null 2>&1; then
                found="$cmd"
                break
            fi
        fi
    done

    # 3. 결과 캐싱 및 반환
    if [ -n "$found" ]; then
        export _SSAFY_PYTHON_CACHE="$found"
        echo "$found"
        return 0
    else
        return 1
    fi
}

_require_python() {
    local cmd
    cmd=$(_ssafy_python_lookup)
    
    if [ -z "$cmd" ]; then
        echo "❌ Python을 찾을 수 없습니다." >&2
        echo "   (Checked: python3, python, py)" >&2
        echo "   기능을 사용하려면 Python을 설치해주세요." >&2
        return 1
    fi
    
    echo "$cmd"
}
