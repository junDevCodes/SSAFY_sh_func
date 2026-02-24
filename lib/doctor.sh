# =============================================================================
# lib/doctor.sh
# 시스템 진단 및 상태 점검
# =============================================================================

_ssafy_doctor__first_line() {
    local line=""
    IFS= read -r line || true
    printf '%s' "$line"
}

_ssafy_doctor__safe_uname() {
    local kernel_name="unknown"
    local kernel_release="unknown"
    local machine="unknown"

    kernel_name="$(uname -s 2>/dev/null || echo "unknown")"
    kernel_release="$(uname -r 2>/dev/null || echo "unknown")"
    machine="$(uname -m 2>/dev/null || echo "unknown")"
    echo "${kernel_name} ${kernel_release} ${machine}"
}

_print_diagnostic_report() {
    echo ""
    if type ui_divider >/dev/null 2>&1; then
        ui_divider "="
        echo "📋 복사용 진단 리포트 (Markdown)"
        ui_divider "="
    else
        echo "==================== 📋 복사용 진단 리포트 (Markdown) ===================="
    fi
    echo "아래 블록을 그대로 복사해 GitHub Issue/DM에 붙여 넣으세요."
    echo "(토큰/설정 원문 같은 민감 정보는 포함하지 않습니다)"
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
        uname_compact="(uname missing)"
    fi

    local git_line="(not installed)"
    if command -v git >/dev/null 2>&1; then
        git_line="$(git --version 2>/dev/null || echo "(check failed)")"
    fi

    local curl_line="(not installed)"
    if command -v curl >/dev/null 2>&1; then
        curl_line="$(curl --version 2>/dev/null | _ssafy_doctor__first_line)"
        [ -z "$curl_line" ] && curl_line="(check failed)"
    fi

    local py_cmd=""
    if type _ssafy_python_lookup >/dev/null 2>&1; then
        py_cmd="$(_ssafy_python_lookup)"
    fi

    local python_line="(not installed)"
    if [ -n "$py_cmd" ]; then
        local py_ver=""
        py_ver="$("$py_cmd" --version 2>&1 | _ssafy_doctor__first_line)"
        py_ver="${py_ver//$'\r'/}"
        if [ -n "$py_ver" ]; then
            python_line="$py_cmd ($py_ver)"
        else
            python_line="$py_cmd"
        fi
    fi

    local ide_editor_disp="${IDE_EDITOR:-"(unset)"}"
    local ide_priority_disp="${IDE_PRIORITY:-"(unset)"}"

    local config_exists="no"
    if [ -n "${ALGO_CONFIG_FILE:-}" ] && [ -f "$ALGO_CONFIG_FILE" ]; then
        config_exists="yes"
    fi

    local cache_exists="no"
    if [ -n "${HOME:-}" ] && [ -f "$HOME/.algo_status_cache" ]; then
        cache_exists="yes"
    fi

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
    printf -- '- 설정파일(~/.algo_config): 존재=%s\n' "$config_exists"
    printf -- '- 상태캐시(~/.algo_status_cache): 존재=%s\n' "$cache_exists"
    echo '```'

    if type ui_divider >/dev/null 2>&1; then
        ui_divider "="
    else
        echo "==============================================================================="
    fi
}

ssafy_algo_doctor() {
    local panel_started=false

    if type init_algo_config >/dev/null 2>&1; then
        init_algo_config
    fi

    if type ui_panel_begin >/dev/null 2>&1; then
        ui_panel_begin "algo-doctor" "환경 진단 리포트"
        panel_started=true
        ui_info "진단 범위=tools/config/network"
    elif type ui_header >/dev/null 2>&1; then
        ui_header "algo-doctor" "환경 진단 리포트"
        ui_info "진단 범위=tools/config/network"
    else
        echo "=================================================="
        echo "  SSAFY Algo Tools Doctor (${ALGO_FUNCTIONS_VERSION})"
        echo "=================================================="
    fi

    if type ui_info >/dev/null 2>&1; then
        ui_info "loaded_from=${ALGO_ROOT_DIR:-unknown}"
        ui_info "version=${ALGO_FUNCTIONS_VERSION:-unknown}"
    else
        echo "[INFO] loaded_from=${ALGO_ROOT_DIR:-unknown}"
        echo "[INFO] version=${ALGO_FUNCTIONS_VERSION:-unknown}"
    fi

    if [ -n "${ALGO_ROOT_DIR:-}" ] && [ -f "$(pwd)/algo_functions.sh" ] && [ "$(cd "$ALGO_ROOT_DIR" 2>/dev/null && pwd)" != "$(pwd)" ]; then
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "현재 디렉터리와 로드 경로가 다릅니다. source ./algo_functions.sh 를 다시 실행하세요."
        else
            echo "[WARN] Loaded path differs from current repo. Run: source ./algo_functions.sh"
        fi
    fi

    if ! _check_service_status; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "서비스 상태 확인에 실패했습니다."
        else
            echo "[ERROR] 서비스 상태 확인에 실패했습니다."
        fi
        if [ "$panel_started" = true ] && type ui_panel_end >/dev/null 2>&1; then
            ui_panel_end
        fi
        return 1
    fi

    local issues=0
    local py_cmd=""

    if type ui_section >/dev/null 2>&1; then
        ui_section "체크 목록"
    fi

    local tool=""
    for tool in git curl base64; do
        if command -v "$tool" >/dev/null 2>&1; then
            if type ui_ok >/dev/null 2>&1; then
                ui_ok "$tool 설치됨: $(command -v "$tool")"
            else
                echo "[OK] $tool 설치됨"
            fi
        else
            if type ui_warn >/dev/null 2>&1; then
                ui_warn "$tool 이(가) 없습니다"
            else
                echo "[WARN] $tool 이(가) 없습니다"
            fi
            issues=$((issues + 1))
        fi
    done

    if type _ssafy_python_lookup >/dev/null 2>&1; then
        py_cmd=$(_ssafy_python_lookup)
    fi
    if [ -n "$py_cmd" ]; then
        if type ui_ok >/dev/null 2>&1; then
            ui_ok "python 사용 가능: $py_cmd"
        else
            echo "[OK] python 사용 가능: $py_cmd"
        fi
    else
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "python 이 없습니다 (python 또는 python3 필요)."
        else
            echo "[WARN] python 이 없습니다"
        fi
        issues=$((issues + 1))
    fi

    if [ -f "$ALGO_CONFIG_FILE" ]; then
        if type ui_ok >/dev/null 2>&1; then
            ui_ok "설정 파일 확인: $ALGO_CONFIG_FILE"
        else
            echo "[OK] 설정 파일 확인: $ALGO_CONFIG_FILE"
        fi
    else
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "설정 파일이 없습니다: $ALGO_CONFIG_FILE"
        else
            echo "[WARN] 설정 파일이 없습니다: $ALGO_CONFIG_FILE"
        fi
        issues=$((issues + 1))
    fi

    if [ -n "${IDE_EDITOR:-}" ]; then
        if command -v "$IDE_EDITOR" >/dev/null 2>&1 || command -v "${IDE_EDITOR}.exe" >/dev/null 2>&1; then
            if type ui_ok >/dev/null 2>&1; then
                ui_ok "IDE 명령 사용 가능: $IDE_EDITOR"
            else
                echo "[OK] IDE 명령 사용 가능: $IDE_EDITOR"
            fi
        else
            if type ui_warn >/dev/null 2>&1; then
                ui_warn "IDE 명령을 찾을 수 없습니다: $IDE_EDITOR"
            else
                echo "[WARN] IDE 명령을 찾을 수 없습니다: $IDE_EDITOR"
            fi
            issues=$((issues + 1))
        fi
    else
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "IDE_EDITOR 설정이 비어 있습니다."
        else
            echo "[WARN] IDE_EDITOR 설정이 비어 있습니다."
        fi
    fi

    if [ -n "${SSAFY_AUTH_TOKEN:-}" ]; then
        if [[ "$SSAFY_AUTH_TOKEN" == "Bearer "* ]]; then
            if type _is_token_expired >/dev/null 2>&1 && _is_token_expired "$SSAFY_AUTH_TOKEN"; then
                if type ui_warn >/dev/null 2>&1; then
                    ui_warn "세션 토큰이 만료되었습니다."
                else
                    echo "[WARN] 세션 토큰이 만료되었습니다."
                fi
                issues=$((issues + 1))
            else
                if type ui_ok >/dev/null 2>&1; then
                    ui_ok "Bearer 토큰이 유효해 보입니다 (로컬 검사)."
                else
                    echo "[OK] Bearer 토큰이 유효해 보입니다 (로컬 검사)."
                fi
            fi
        else
            local status_code=""
            status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $SSAFY_AUTH_TOKEN" "${SSAFY_BASE_URL:-https://lab.ssafy.com}/api/v4/user" 2>/dev/null || echo "fail")
            if [ "$status_code" = "200" ]; then
                if type ui_ok >/dev/null 2>&1; then
                    ui_ok "GitLab API 인증 확인 통과."
                else
                    echo "[OK] GitLab API 인증 확인 통과."
                fi
            else
                if type ui_warn >/dev/null 2>&1; then
                    ui_warn "GitLab API 인증 확인 실패 (code=$status_code)."
                else
                    echo "[WARN] GitLab API 인증 확인 실패 (code=$status_code)."
                fi
                issues=$((issues + 1))
            fi
        fi
    else
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "SSAFY_AUTH_TOKEN 이 설정되지 않았습니다 (세션 전용 값)."
        else
            echo "[WARN] SSAFY_AUTH_TOKEN 이 설정되지 않았습니다"
        fi
    fi

    if [ "$issues" -eq 0 ]; then
        if type ui_ok >/dev/null 2>&1; then
            ui_ok "PASS: 모든 항목이 정상입니다."
        else
            echo "[OK] PASS: 모든 항목이 정상입니다."
        fi
    else
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "WARN: 문제 항목 $issues개를 찾았습니다."
        else
            echo "[WARN] 문제 항목 $issues개를 찾았습니다."
        fi
    fi

    if [ "$panel_started" = true ] && type ui_panel_end >/dev/null 2>&1; then
        ui_panel_end
    fi

    _print_diagnostic_report

    if _is_interactive; then
        local action=""
        echo ""
        if type ui_hint >/dev/null 2>&1; then
            ui_hint "동작: [Enter]=종료, r=재진단, c=리포트 재출력"
        else
            echo "동작: [Enter]=종료, r=재진단, c=리포트 재출력"
        fi
        read -r action
        case "$action" in
            r|R)
                ssafy_algo_doctor
                return $?
                ;;
            c|C)
                _print_diagnostic_report
                ;;
        esac
    fi
}
