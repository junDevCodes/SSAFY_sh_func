# =============================================================================
# lib/auth.sh
# Authentication & Token Management
# =============================================================================

# [Security V7.7] JWT 토큰 만료 체크
# Returns 0 (true) if expired, 1 (false) if valid
_is_token_expired() {
    local token="$1"
    
    # Bearer 접두사 제거
    local jwt="${token#Bearer }"
    
    # JWT 포맷 확인 (header.payload.signature)
    if [[ ! "$jwt" == *"."*"."* ]]; then
        return 0  # 잘못된 형식 = 만료로 처리
    fi
    
    # Payload 추출 (두 번째 파트)
    local payload=$(echo "$jwt" | cut -d'.' -f2)
    
    # Base64 URL-safe 디코딩을 위한 패딩 추가
    local padding=$((4 - ${#payload} % 4))
    if [ $padding -lt 4 ]; then
        payload="${payload}$(printf '=%.0s' $(seq 1 $padding))"
    fi
    
    # Base64 디코딩 및 exp 추출
    # [V8.1 Refactor] Use shared python resolution
    local exp=""
    local py_cmd
    
    # python_env.sh가 로드되지 않았을 경우를 대비한 안전 장치 (혹은 sourced 가정)
    if type _ssafy_python_lookup >/dev/null 2>&1; then
        py_cmd=$(_ssafy_python_lookup)
    fi

    if [ -n "$py_cmd" ]; then
        exp=$(echo "$payload" | "$py_cmd" -c "
import sys, base64, json
try:
    payload = sys.stdin.read().strip()
    # URL-safe base64 decoding
    payload = payload.replace('-', '+').replace('_', '/')
    decoded = base64.b64decode(payload)
    data = json.loads(decoded)
    print(data.get('exp', 0))
except:
    print(0)
" 2>/dev/null)
    else
        return 0  # Python 없으면 만료로 처리 (보수적 접근)
    fi
    
    # 현재 시간과 비교
    local now=$(date +%s)
    if [ -z "$exp" ] || [ "$exp" = "0" ]; then
        return 0  # exp 없으면 만료로 처리
    fi
    
    if [ "$now" -ge "$exp" ]; then
        return 0  # 만료됨
    else
        return 1  # 유효함
    fi
}

# [Security V7.7] 세션 전용 토큰 관리
# 토큰이 환경변수에 없으면 사용자에게 입력 요청
_ensure_token() {
    if [ -z "${SSAFY_AUTH_TOKEN:-}" ]; then
        if _is_interactive; then
            echo ""
            echo "🔐 SSAFY 토큰이 필요합니다."
            echo "   (토큰은 이 터미널 세션에서만 유지됩니다)"
            echo "   (터미널 종료 시 자동으로 삭제됩니다)"
            echo ""
            read -r -s -p "🔑 Token (Bearer ...): " token_input
            echo ""
            
            if [ -n "$token_input" ]; then
                export SSAFY_AUTH_TOKEN="$token_input"
                echo "✅ 토큰이 세션에 저장되었습니다."
                return 0
            else
                echo "❌ 토큰이 입력되지 않았습니다."
                return 1
            fi
        else
            return 1
        fi
    fi
    return 0
}

# =============================================================================
# _read_masked_input - 비밀번호 입력 시 Asterisk(*) 표시
# =============================================================================
_read_masked_input() {
    local prompt="$1"
    local password=""
    local char
    
    # -n: 줄바꿈 없음 (프롬프트 옆에 입력)
    echo -n "$prompt" >&2
    
    while IFS= read -r -s -n 1 char; do
        # Enter Key (공백 또는 널문자로 감지될 수 있음)
        if [[ -z "$char" ]]; then
            # echo "" >&2 # 줄바꿈 (gitup에서 처리하도록 함)
            break
        fi
        
        # Backspace handling (ASCII 127 or 08)
        if [[ "$char" == $'\x7f' || "$char" == $'\x08' ]]; then
            if [ ${#password} -gt 0 ]; then
                password="${password%?}"
                echo -ne "\b \b" >&2 # 지우기 효과
            fi
        else
            password+="$char"
            echo -n "*" >&2
        fi
    done
    
    echo "$password"
}
