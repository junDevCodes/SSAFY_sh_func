# =============================================================================
# lib/doctor.sh
# System Diagnosis & Health Check
# =============================================================================

# =============================================================================
# algo-doctor - ?쒖뒪??諛??ㅼ젙 吏꾨떒 ?꾧뎄 (V7.0) (V7.6 ?ㅼ엫?ㅽ럹?댁뒪)
# =============================================================================
#
# ?덈궡:
# - ???뚯씪??異쒕젰? ?ъ슜?먭? 洹몃?濡?蹂듭궗?댁꽌 ?댁뒋 ?몃옒而ㅼ뿉 遺숈뿬?ｋ뒗 寃껋쓣 ?꾩젣濡??⑸땲??
# - ?좏겙/?ㅼ젙 ?댁슜 ??誘쇨컧?뺣낫???덈? 異쒕젰?섏? ?딆뒿?덈떎.

_ssafy_doctor__first_line() {
    # ?쒖? 異쒕젰?먯꽌 泥?以꾨쭔 ?덉쟾?섍쾶 媛?몄샃?덈떎.
    # (head ?섏〈 ?놁씠 bash built-in read ?ъ슜)
    local line=""
    IFS= read -r line || true
    printf '%s' "$line"
}

_ssafy_doctor__safe_uname() {
    # ?몄뒪?몃챸(媛쒖씤 ?앸퀎 媛???뺣낫)???ы븿?????덈뒗 uname -a ???
    # 理쒖냼?쒖쓽 OS/而ㅻ꼸/?꾪궎?띿쿂 ?뺣낫留?異쒕젰?⑸땲??
    local kernel_name="unknown"
    local kernel_release="unknown"
    local machine="unknown"
    kernel_name="$(uname -s 2>/dev/null || echo "unknown")"
    kernel_release="$(uname -r 2>/dev/null || echo "unknown")"
    machine="$(uname -m 2>/dev/null || echo "unknown")"
    echo "${kernel_name} ${kernel_release} ${machine}"
}

_print_diagnostic_report() {
    # ?댁뒋 ?몃옒而ㅼ뿉 諛붾줈 遺숈뿬?ｊ린 醫뗭? Markdown 由ы룷??釉붾줉??異쒕젰?⑸땲??
    # - 媛쒖씤?뺣낫/誘쇨컧?뺣낫(?좏겙, ?ㅼ젙?뚯씪 ?댁슜, ?ъ슜?먮챸 ?? 異쒕젰 湲덉?
    # - 寃쎈줈??理쒖냼 ?뺣낫留??쒓났 (留덉?留??대뜑留?
    echo ""
    echo "==================== 蹂듭궗??吏꾨떒 由ы룷??(Markdown) ===================="
    echo "?꾨옒 釉붾줉??洹몃?濡?蹂듭궗?댁꽌 GitHub Issue/DM??遺숈뿬?ｌ뼱二쇱꽭??"
    echo "(媛쒖씤?뺣낫/?좏겙/?ㅼ젙 ?댁슜? ?ы븿?섏? ?딆뒿?덈떎)"
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
        uname_compact="(uname ?놁쓬)"
    fi

    local git_line="(誘몄꽕移?"
    if command -v git >/dev/null 2>&1; then
        git_line="$(git --version 2>/dev/null || echo "(?뺤씤 ?ㅽ뙣)")"
    fi

    local curl_line="(誘몄꽕移?"
    if command -v curl >/dev/null 2>&1; then
        curl_line="$(curl --version 2>/dev/null | _ssafy_doctor__first_line)"
        [ -z "$curl_line" ] && curl_line="(?뺤씤 ?ㅽ뙣)"
    fi

    local py_cmd=""
    if type _ssafy_python_lookup >/dev/null 2>&1; then
        py_cmd="$(_ssafy_python_lookup)"
    fi

    local python_line="(誘몄꽕移?"
    if [ -n "$py_cmd" ]; then
        local py_ver=""
        py_ver="$("$py_cmd" --version 2>&1 | _ssafy_doctor__first_line)"
        # Windows(Git Bash) ?섍꼍?먯꽌 CRLF(\r) ?욎씠??耳?댁뒪 ?뺣━
        py_ver="${py_ver//$'\r'/}"
        if [ -n "$py_ver" ]; then
            python_line="$py_cmd ($py_ver)"
        else
            python_line="$py_cmd"
        fi
    fi

    local ide_editor_disp="${IDE_EDITOR:-"(誘몄꽕??"}"
    local ide_priority_disp="${IDE_PRIORITY:-"(誘몄꽕??"}"

    local config_exists="no"
    if [ -n "${ALGO_CONFIG_FILE:-}" ] && [ -f "$ALGO_CONFIG_FILE" ]; then
        config_exists="yes"
    fi

    local cache_exists="no"
    if [ -n "${HOME:-}" ] && [ -f "$HOME/.algo_status_cache" ]; then
        cache_exists="yes"
    fi

    # Markdown 肄붾뱶釉붾줉: here-doc(諛깊떛 而ㅻ㎤??移섑솚) ?댁뒋瑜??쇳븯湲??꾪빐 echo/printf濡?援ъ꽦?⑸땲??
    echo '```text'
    echo '[SSAFY Algo Tools Doctor 由ы룷??'
    printf -- '- ?앹꽦?쒓컖(UTC): %s\n' "$now_utc"
    printf -- '- ALGO_FUNCTIONS_VERSION: %s\n' "${ALGO_FUNCTIONS_VERSION:-unknown}"
    printf -- '- OSTYPE: %s\n' "$ostype"
    printf -- '- uname(留덉뒪??: %s\n' "$uname_compact"
    printf -- '- SHELL: %s\n' "$shell_path"
    printf -- '- PWD(留덉뒪??: .../%s\n' "$pwd_tail"
    printf -- '- Git: %s\n' "$git_line"
    printf -- '- Curl: %s\n' "$curl_line"
    printf -- '- Python: %s\n' "$python_line"
    printf -- '- IDE_EDITOR: %s\n' "$ide_editor_disp"
    printf -- '- IDE_PRIORITY: %s\n' "$ide_priority_disp"
    printf -- '- ?ㅼ젙?뚯씪(~/.algo_config): 議댁옱: %s\n' "$config_exists"
    printf -- '- ?곹깭罹먯떆(~/.algo_status_cache): 議댁옱: %s\n' "$cache_exists"
    echo '```'

    echo "======================================================================="
}

ssafy_algo_doctor() {
    if type init_algo_config >/dev/null 2>&1; then
        init_algo_config
    fi

    if type ui_header >/dev/null 2>&1; then
        ui_header "algo-doctor" "version=${ALGO_FUNCTIONS_VERSION:-unknown}"
        ui_info "scope=tools/config/network"
    else
        echo "=================================================="
        echo "  SSAFY Algo Tools Doctor (${ALGO_FUNCTIONS_VERSION})"
        echo "=================================================="
    fi

    if ! _check_service_status; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "Service status check failed."
        else
            echo "[ERROR] Service status check failed."
        fi
        return 1
    fi

    local issues=0
    local py_cmd=""

    if type ui_section >/dev/null 2>&1; then
        ui_section "Checks"
    fi

    for tool in git curl base64; do
        if command -v "$tool" >/dev/null 2>&1; then
            if type ui_ok >/dev/null 2>&1; then
                ui_ok "$tool installed: $(command -v "$tool")"
            else
                echo "[OK] $tool installed"
            fi
        else
            if type ui_warn >/dev/null 2>&1; then
                ui_warn "$tool is missing"
            else
                echo "[WARN] $tool is missing"
            fi
            issues=$((issues + 1))
        fi
    done

    if type _ssafy_python_lookup >/dev/null 2>&1; then
        py_cmd=$(_ssafy_python_lookup)
    fi
    if [ -n "$py_cmd" ]; then
        if type ui_ok >/dev/null 2>&1; then
            ui_ok "python available: $py_cmd"
        else
            echo "[OK] python available: $py_cmd"
        fi
    else
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "python is missing (python or python3 required)."
        else
            echo "[WARN] python is missing"
        fi
        issues=$((issues + 1))
    fi

    if [ -f "$ALGO_CONFIG_FILE" ]; then
        if type ui_ok >/dev/null 2>&1; then
            ui_ok "config found: $ALGO_CONFIG_FILE"
        else
            echo "[OK] config found: $ALGO_CONFIG_FILE"
        fi
    else
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "config file is missing: $ALGO_CONFIG_FILE"
        else
            echo "[WARN] config file is missing: $ALGO_CONFIG_FILE"
        fi
        issues=$((issues + 1))
    fi

    if [ -n "${IDE_EDITOR:-}" ]; then
        if command -v "$IDE_EDITOR" >/dev/null 2>&1 || command -v "${IDE_EDITOR}.exe" >/dev/null 2>&1; then
            if type ui_ok >/dev/null 2>&1; then
                ui_ok "IDE command available: $IDE_EDITOR"
            else
                echo "[OK] IDE command available: $IDE_EDITOR"
            fi
        else
            if type ui_warn >/dev/null 2>&1; then
                ui_warn "IDE command not found: $IDE_EDITOR"
            else
                echo "[WARN] IDE command not found: $IDE_EDITOR"
            fi
            issues=$((issues + 1))
        fi
    else
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "IDE_EDITOR is not configured."
        else
            echo "[WARN] IDE_EDITOR is not configured."
        fi
    fi

    if [ -n "${SSAFY_AUTH_TOKEN:-}" ]; then
        if [[ "$SSAFY_AUTH_TOKEN" == "Bearer "* ]]; then
            if type _is_token_expired >/dev/null 2>&1 && _is_token_expired "$SSAFY_AUTH_TOKEN"; then
                if type ui_warn >/dev/null 2>&1; then
                    ui_warn "Session token is expired."
                else
                    echo "[WARN] Session token is expired."
                fi
                issues=$((issues + 1))
            else
                if type ui_ok >/dev/null 2>&1; then
                    ui_ok "Bearer token looks valid (local check)."
                else
                    echo "[OK] Bearer token looks valid (local check)."
                fi
            fi
        else
            local status_code=""
            status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $SSAFY_AUTH_TOKEN" "${SSAFY_BASE_URL:-https://lab.ssafy.com}/api/v4/user" 2>/dev/null || echo "fail")
            if [ "$status_code" = "200" ]; then
                if type ui_ok >/dev/null 2>&1; then
                    ui_ok "GitLab API auth check passed."
                else
                    echo "[OK] GitLab API auth check passed."
                fi
            else
                if type ui_warn >/dev/null 2>&1; then
                    ui_warn "GitLab API auth check failed (code=$status_code)."
                else
                    echo "[WARN] GitLab API auth check failed (code=$status_code)."
                fi
                issues=$((issues + 1))
            fi
        fi
    else
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "SSAFY_AUTH_TOKEN is not set (session-only value)."
        else
            echo "[WARN] SSAFY_AUTH_TOKEN is not set"
        fi
    fi

    if [ $issues -eq 0 ]; then
        if type ui_ok >/dev/null 2>&1; then
            ui_ok "PASS: all checks look healthy."
        else
            echo "[OK] PASS: all checks look healthy."
        fi
    else
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "WARN: found $issues issue(s)."
        else
            echo "[WARN] found $issues issue(s)."
        fi
    fi

    _print_diagnostic_report

    if _is_interactive; then
        local action=""
        echo ""
        echo "Actions: [Enter]=exit, r=rerun, c=reprint report"
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