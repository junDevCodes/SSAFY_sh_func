# =============================================================================
# lib/utils.sh
# Common Utility Functions
# =============================================================================

_is_interactive() {
    [ -t 0 ] && [ -t 1 ]
}

_ensure_ssafy_config() {
    # Ensure config loaded
    if type init_algo_config >/dev/null 2>&1; then init_algo_config; fi

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
}

# =============================================================================
# Kill Switch implementation (V8.1)
# =============================================================================
_check_service_status() {
    # Default: raw github url
    local status_url="${ALGO_STATUS_URL:-https://raw.githubusercontent.com/jylee-ssafy/SSAFY_sh_func/main/status.json}"
    
    # [DEBUG]
    # echo "DEBUG: checking status from $status_url" >&2

    # 1. Fetch JSON (timeout 2s)
    local json=""
    
    # URL이 file:// 로 시작하면 cat 사용 (curl 호환성 문제 방지)
    if [[ "$status_url" == file://* ]]; then
        local file_path="${status_url#file://}"
        # Git Bash 등에서 /c/Users... 경로 문제 해결을 위해 단순화
        if [ -f "$file_path" ]; then
            json=$(cat "$file_path")
        else
            # 윈도우 경로 이슈일 수 있으니 curl 시도
             if command -v curl >/dev/null 2>&1; then
                json=$(curl -s --max-time 2 "$status_url" || echo "")
            fi
        fi
    else
        if command -v curl >/dev/null 2>&1; then
            json=$(curl -s --max-time 2 "$status_url" || echo "")
        fi
    fi
    
    # [DEBUG]
    # echo "DEBUG: json content: $json" >&2
    
    if [ -z "$json" ]; then
        # 네트워크 오류 등 -> Fail Open (정상 진행)
        return 0
    fi
    
    # 2. Parse Status
    # Python이 있으면 Python 사용
    local status="active"
    local message=""
    local min_version="V1.0.0"
    
    if type _ssafy_python_lookup >/dev/null 2>&1; then
         local py_cmd=$(_ssafy_python_lookup)
         if [ -n "$py_cmd" ]; then
             IFS='|' read -r status message min_version <<< $(echo "$json" | "$py_cmd" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('status', 'active'), d.get('message', ''), d.get('min_version', 'V1.0.0'), sep='|')
except:
    print('active||V1.0.0')
" 2>/dev/null)
         fi
    else
        # Fallback (grep/sed)
        status=$(echo "$json" | grep -o '"status": *"[^"]*"' | cut -d'"' -f4)
        message=$(echo "$json" | grep -o '"message": *"[^"]*"' | cut -d'"' -f4)
        min_version=$(echo "$json" | grep -o '"min_version": *"[^"]*"' | cut -d'"' -f4)
    fi
    
    # 기본값 처리
    [ -z "$status" ] && status="active"
    
    # 3. Handle Status
    case "$status" in
        active)
            ;;
        maintenance)
            echo "⚠️  [공지] $message"
            ;;
        outage)
            echo "❌ [긴급] 서비스가 일시 중단되었습니다."
            echo "   사유: $message"
            return 1 # Stop execution
            ;;
    esac
    
    # 4. Check Min Version
    # Version Compare Logic need
    # (Simple string compare for now, or skip if complex)
    # ALGO_FUNCTIONS_VERSION is global
    if [[ "$status" != "outage" ]] && [ -n "${ALGO_FUNCTIONS_VERSION:-}" ]; then
        if [[ "$ALGO_FUNCTIONS_VERSION" < "$min_version" ]]; then
             echo "⚠️  필수 업데이트가 필요합니다! (Current: $ALGO_FUNCTIONS_VERSION < Min: $min_version)"
             echo "   👉 algo-update 를 실행해주세요."
             return 2 # Force update required
        fi
    fi
    
    return 0
}
