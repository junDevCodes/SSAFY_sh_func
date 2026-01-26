# =============================================================================
# lib/doctor.sh
# System Diagnosis & Health Check
# =============================================================================

# =============================================================================
# algo-doctor - 시스템 및 설정 진단 도구 (V7.0) (V7.6 네임스페이스)
# =============================================================================
ssafy_algo_doctor() {
    # Ensure config/auth/ide are loaded
    if type init_algo_config >/dev/null 2>&1; then init_algo_config; fi

    echo "=================================================="
    echo "  SSAFY Algo Tools Doctor (${ALGO_FUNCTIONS_VERSION})"
    echo "=================================================="
    echo ""
    
    local issues=0
    
    # [1] 필수 도구 점검
    echo "1️⃣  필수 도구 점검"
    for tool in git curl base64; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "   ✅ $tool: 설치됨 ($(command -v "$tool"))"
        else
            echo "   ❌ $tool: 설치되지 않음!"
            ((issues++))
        fi
    done
    
    # Python check (allow python or python3)
    # Use _ssafy_python_lookup if available
    local py_cmd=""
    if type _ssafy_python_lookup >/dev/null 2>&1; then
        py_cmd=$(_ssafy_python_lookup)
    fi

    if [ -n "$py_cmd" ]; then
        echo "   ✅ python: 설치됨 ($py_cmd)"
    else
        echo "   ❌ python: 설치되지 않음! (python3 또는 python 필요)"
        ((issues++))
    fi
    
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
        
        # [Security V7.7] 토큰 세션 상태 체크 (만료 여부 포함)
        if [ -n "${SSAFY_AUTH_TOKEN:-}" ]; then
            if _is_token_expired "$SSAFY_AUTH_TOKEN"; then
                echo "   ⚠️  토큰 상태: 만료됨 (재입력 필요)"
                echo "      (gitup 실행 시 새 토큰을 입력하세요)"
                ((issues++))
            else
                # 남은 시간 계산
                local jwt="${SSAFY_AUTH_TOKEN#Bearer }"
                local payload=$(echo "$jwt" | cut -d'.' -f2)
                
                # Payload Decoding for exp (Use Python)
                local exp_time=0
                if [ -n "$py_cmd" ]; then
                    exp_time=$(echo "$payload" | "$py_cmd" -c "
import sys, base64, json
try:
    p = sys.stdin.read().strip().replace('-','+').replace('_','/')
    p += '=' * (4 - len(p) % 4) if len(p) % 4 else ''
    print(json.loads(base64.b64decode(p)).get('exp',0))
except: print(0)
" 2>/dev/null || echo "0")
                fi

                local now=$(date +%s)
                local remaining=$((exp_time - now))
                local hours=$((remaining / 3600))
                local mins=$(((remaining % 3600) / 60))
                
                echo "   ✅ 토큰 상태: 유효 (세션 전용)"
                echo "      (남은 시간: ${hours}시간 ${mins}분)"
            fi
        else
            echo "   ℹ️  토큰 미설정 (gitup 실행 시 입력 요청)"
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
    
    # 토큰 타입에 따라 검증 방식 분기
    if [ -n "$SSAFY_AUTH_TOKEN" ]; then
        if [[ "$SSAFY_AUTH_TOKEN" == "Bearer "* ]]; then
            # [Case A] LMS Bearer Token (JWT)
            # GitLab API로 검증 불가하므로, 형식만 체크합니다.
            
            if [[ "$SSAFY_AUTH_TOKEN" == *"ey"* ]]; then
                 echo "   ✅ 인증 상태: 유효 (SSAFY LMS Bearer Token)"
                 echo "      (참고: LMS 토큰은 로컬에서 형식만 검증되었습니다)"
            else
                 echo "   ❌ 인증 상태: 토큰 형식이 올바르지 않음 (Bearer ...)"
                 ((issues++))
            fi
        else
            # [Case B] GitLab Private Token (glpat-...)
            # GitLab API 호출로 검증
            local status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $SSAFY_AUTH_TOKEN" "${SSAFY_BASE_URL:-https://lab.ssafy.com}/api/v4/user" || echo "fail")
            
            if [ "$status_code" == "200" ]; then
                echo "   ✅ 인증 상태: 유효함 (연결 성공)"
            elif [ "$status_code" == "401" ]; then
                 echo "   ❌ 인증 상태: 토큰 만료 또는 잘못됨 (401)"
                 echo "   💡 LMS 토큰이라면 'Bearer '로 시작해야 합니다."
                 ((issues++))
            elif [ "$status_code" == "fail" ]; then
                 echo "   ⚠️  서버 연결 실패 (네트워크 확인)"
            else
                 echo "   ❓ 응답 코드: $status_code"
            fi
        fi
    else
        echo "   ⚠️  토큰 미설정 (검증 건너뜀)"
    fi

    echo ""
    echo "=================================================="
    if [ $issues -eq 0 ]; then
        echo "  모든 시스템이 정상입니다!"
    else
        echo "⚠️  $issues 건의 문제점이 발견되었습니다."
    fi
    echo "=================================================="
}
