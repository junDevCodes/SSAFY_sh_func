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
