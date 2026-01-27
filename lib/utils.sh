# =============================================================================
# lib/utils.sh
# Common Utility Functions
# =============================================================================

_is_interactive() {
    [ -t 0 ] && [ -t 1 ]
}

# Phase 4 Task 4-2: sed 공통 함수 추출 (macOS/Linux 호환성)
_sed_inplace() {
    local pattern="$1"
    local file="$2"
    
    if sed --version >/dev/null 2>&1; then
        # GNU sed (Linux)
        sed -i "$pattern" "$file"
    else
        # BSD sed (macOS)
        sed -i '' "$pattern" "$file"
    fi
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
    # Phase 4 Task 4-4: 캐싱 추가 (24시간)
    # Phase 5 Task 5-1: 변수 스코프 수정
    local json=""
    local cache_file="/tmp/algo_status_cache"
    local cache_max_age=86400  # 24시간
    
    # 캐시 확인
    if [ -f "$cache_file" ]; then
        local cache_time
        if stat --version >/dev/null 2>&1; then
            # GNU stat (Linux)
            cache_time=$(stat -c %Y "$cache_file" 2>/dev/null)
        else
            # BSD stat (macOS)
            cache_time=$(stat -f %m "$cache_file" 2>/dev/null)
        fi
        local current_time=$(date +%s)
        if [ -n "$cache_time" ] && [ $((current_time - cache_time)) -lt $cache_max_age ]; then
            # 캐시에서 읽기
            local cached_json=$(cat "$cache_file" 2>/dev/null)
            if [ -n "$cached_json" ]; then
                # 캐시된 JSON 파싱 (아래 로직 재사용)
                json="$cached_json"
            fi
            # else: json은 이미 ""로 초기화됨
        fi
        # else: json은 이미 ""로 초기화됨
    fi
    
    # 네트워크 요청 (캐시가 없거나 만료된 경우)
    if [ -z "$json" ]; then
        # Default: raw github url
        local status_url="${ALGO_STATUS_URL:-https://raw.githubusercontent.com/jylee-ssafy/SSAFY_sh_func/main/status.json}"
        
        # URL이 file:// 로 시작하면 cat 사용 (curl 호환성 문제 방지)
        if [[ "$status_url" == file://* ]]; then
            local file_path="${status_url#file://}"
            if [ -f "$file_path" ]; then
                json=$(cat "$file_path")
            else
                if command -v curl >/dev/null 2>&1; then
                    json=$(curl -s --max-time 2 "$status_url" || echo "")
                fi
            fi
        else
            if command -v curl >/dev/null 2>&1; then
                json=$(curl -s --max-time 2 "$status_url" || echo "")
            fi
        fi
        
        # 캐시에 저장 (백그라운드)
        if [ -n "$json" ]; then
            echo "$json" > "$cache_file" 2>/dev/null &
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
