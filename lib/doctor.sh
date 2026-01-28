# =============================================================================
# lib/doctor.sh
# System Diagnosis & Health Check
# =============================================================================

# =============================================================================
# algo-doctor - 시스템 및 설정 진단 도구 (V7.0) (V7.6 네임스페이스)
# =============================================================================
#
# 안내:
# - 이 파일의 출력은 사용자가 그대로 복사해서 이슈 트래커에 붙여넣는 것을 전제로 합니다.
# - 토큰/설정 내용 등 민감정보는 절대 출력하지 않습니다.

_ssafy_doctor__first_line() {
    # 표준 출력에서 첫 줄만 안전하게 가져옵니다.
    # (head 의존 없이 bash built-in read 사용)
    local line=""
    IFS= read -r line || true
    printf '%s' "$line"
}

_ssafy_doctor__safe_uname() {
    # 호스트명(개인 식별 가능 정보)이 포함될 수 있는 uname -a 대신,
    # 최소한의 OS/커널/아키텍처 정보만 출력합니다.
    local kernel_name="unknown"
    local kernel_release="unknown"
    local machine="unknown"
    kernel_name="$(uname -s 2>/dev/null || echo "unknown")"
    kernel_release="$(uname -r 2>/dev/null || echo "unknown")"
    machine="$(uname -m 2>/dev/null || echo "unknown")"
    echo "${kernel_name} ${kernel_release} ${machine}"
}

_print_diagnostic_report() {
    # 이슈 트래커에 바로 붙여넣기 좋은 Markdown 리포트 블록을 출력합니다.
    # - 개인정보/민감정보(토큰, 설정파일 내용, 사용자명 등) 출력 금지
    # - 경로는 최소 정보만 제공 (마지막 폴더만)
    echo ""
    echo "==================== 복사용 진단 리포트 (Markdown) ===================="
    echo "아래 블록을 그대로 복사해서 GitHub Issue/DM에 붙여넣어주세요."
    echo "(개인정보/토큰/설정 내용은 포함되지 않습니다)"
    echo ""

    local now_utc=""
    now_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date 2>/dev/null || echo "unknown")"

    local ostype="${OSTYPE:-unknown}"
    local shell_path="${SHELL:-unknown}"

    local pwd_tail="(unknown)"
    if [ -n "${PWD:-}" ]; then
        pwd_tail="${PWD##*/}"
    fi

    local uname_compact=""
    if command -v uname >/dev/null 2>&1; then
        uname_compact="$(_ssafy_doctor__safe_uname)"
    else
        uname_compact="(uname 없음)"
    fi

    local git_line="(미설치)"
    if command -v git >/dev/null 2>&1; then
        git_line="$(git --version 2>/dev/null || echo "(확인 실패)")"
    fi

    local curl_line="(미설치)"
    if command -v curl >/dev/null 2>&1; then
        curl_line="$(curl --version 2>/dev/null | _ssafy_doctor__first_line)"
        [ -z "$curl_line" ] && curl_line="(확인 실패)"
    fi

    local py_cmd=""
    if type _ssafy_python_lookup >/dev/null 2>&1; then
        py_cmd="$(_ssafy_python_lookup)"
    fi

    local python_line="(미설치)"
    if [ -n "$py_cmd" ]; then
        local py_ver=""
        py_ver="$("$py_cmd" --version 2>&1 | _ssafy_doctor__first_line)"
        # Windows(Git Bash) 환경에서 CRLF(\r) 섞이는 케이스 정리
        py_ver="${py_ver//$'\r'/}"
        if [ -n "$py_ver" ]; then
            python_line="$py_cmd ($py_ver)"
        else
            python_line="$py_cmd"
        fi
    fi

    local ide_editor_disp="${IDE_EDITOR:-"(미설정)"}"
    local ide_priority_disp="${IDE_PRIORITY:-"(미설정)"}"

    local config_exists="no"
    if [ -n "${ALGO_CONFIG_FILE:-}" ] && [ -f "$ALGO_CONFIG_FILE" ]; then
        config_exists="yes"
    fi

    local cache_exists="no"
    if [ -n "${HOME:-}" ] && [ -f "$HOME/.algo_status_cache" ]; then
        cache_exists="yes"
    fi

    # Markdown 코드블록: here-doc(백틱 커맨드 치환) 이슈를 피하기 위해 echo/printf로 구성합니다.
    echo '```text'
    echo '[SSAFY Algo Tools Doctor 리포트]'
    printf -- '- 생성시각(UTC): %s\n' "$now_utc"
    printf -- '- ALGO_FUNCTIONS_VERSION: %s\n' "${ALGO_FUNCTIONS_VERSION:-unknown}"
    printf -- '- OSTYPE: %s\n' "$ostype"
    printf -- '- uname(마스킹): %s\n' "$uname_compact"
    printf -- '- SHELL: %s\n' "$shell_path"
    printf -- '- PWD(마스킹): .../%s\n' "$pwd_tail"
    printf -- '- Git: %s\n' "$git_line"
    printf -- '- Curl: %s\n' "$curl_line"
    printf -- '- Python: %s\n' "$python_line"
    printf -- '- IDE_EDITOR: %s\n' "$ide_editor_disp"
    printf -- '- IDE_PRIORITY: %s\n' "$ide_priority_disp"
    printf -- '- 설정파일(~/.algo_config): 존재: %s\n' "$config_exists"
    printf -- '- 상태캐시(~/.algo_status_cache): 존재: %s\n' "$cache_exists"
    echo '```'

    echo "======================================================================="
}

ssafy_algo_doctor() {
    # Ensure config/auth/ide are loaded
    if type init_algo_config >/dev/null 2>&1; then init_algo_config; fi

    echo "=================================================="
    echo "  SSAFY Algo Tools Doctor (${ALGO_FUNCTIONS_VERSION})"
    echo "=================================================="
    echo ""
    
    # [Kill Switch Check]
    if ! _check_service_status; then
        echo "⚠️  서비스 상태 확인 중 문제가 발생했습니다 (또는 점검 중)."
        return 1
    fi
    
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
        echo "   ❌ 설정 파일 없음 (~/.algo_config)"
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

    # 사용자 제보 UX: 마지막에 복사용 Markdown 리포트 블록 출력
    _print_diagnostic_report
}
