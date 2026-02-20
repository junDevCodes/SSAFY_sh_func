# =============================================================================
# lib/config.sh
# Configuration management & initialization
# =============================================================================

ALGO_CONFIG_FILE="$HOME/.algo_config"

init_algo_config() {
    if [ ! -f "$ALGO_CONFIG_FILE" ]; then
        echo "[INFO] creating config file: $ALGO_CONFIG_FILE"
        cat <<EOF > "$ALGO_CONFIG_FILE"
# SSAFY Algo Functions Config
ALGO_BASE_DIR="$HOME/algos"
GIT_DEFAULT_BRANCH="main"
GIT_COMMIT_PREFIX="solve"
GIT_AUTO_PUSH=true
IDE_EDITOR=""
SSAFY_BASE_URL="https://lab.ssafy.com"
SSAFY_USER_ID=""
EOF
    fi

    # shellcheck disable=SC1090
    source "$ALGO_CONFIG_FILE"

    if [ -z "${ALGO_BASE_DIR:-}" ]; then
        echo 'ALGO_BASE_DIR="$HOME/algos"' >> "$ALGO_CONFIG_FILE"
        export ALGO_BASE_DIR="$HOME/algos"
    fi
}

_get_config_value() {
    local key="$1"
    if [ -f "$ALGO_CONFIG_FILE" ]; then
        grep "^${key}=" "$ALGO_CONFIG_FILE" | cut -d'=' -f2- | tr -d '"'
    else
        echo ""
    fi
}

_set_config_value() {
    local key="$1"
    local value="$2"

    if [ "$key" = "SSAFY_AUTH_TOKEN" ]; then
        export SSAFY_AUTH_TOKEN="$value"
        if type ui_info >/dev/null 2>&1; then
            ui_info "토큰은 세션에만 저장됩니다."
        else
            echo "[INFO] Token is stored in session only."
        fi
        return 0
    fi

    if [ ! -f "$ALGO_CONFIG_FILE" ]; then
        init_algo_config
    fi

    if grep -q "^${key}=" "$ALGO_CONFIG_FILE"; then
        _sed_inplace "s|^${key}=.*|${key}=\"${value}\"|" "$ALGO_CONFIG_FILE"
    else
        echo "${key}=\"${value}\"" >> "$ALGO_CONFIG_FILE"
    fi

    export "${key}=${value}"
}

_ssafy_algo_config_find_wizard() {
    local script_dir="${ALGO_ROOT_DIR:-$HOME/.ssafy-tools}"

    if [ -f "$script_dir/algo_config_wizard.py" ]; then
        printf '%s' "$script_dir/algo_config_wizard.py"
        return 0
    fi
    if [ -f "$HOME/Desktop/SSAFY_sh_func/algo_config_wizard.py" ]; then
        printf '%s' "$HOME/Desktop/SSAFY_sh_func/algo_config_wizard.py"
        return 0
    fi
    if [ -f "$HOME/.ssafy-tools/algo_config_wizard.py" ]; then
        printf '%s' "$HOME/.ssafy-tools/algo_config_wizard.py"
        return 0
    fi
    return 1
}

_ssafy_algo_config_reload() {
    if [ -f "$HOME/.bashrc" ]; then
        # shellcheck disable=SC1090
        source "$HOME/.bashrc"
    else
        init_algo_config
    fi
}

_ssafy_algo_config_run_gui() {
    local wizard=""
    local py_cmd=""

    wizard=$(_ssafy_algo_config_find_wizard 2>/dev/null || true)
    if [ -z "$wizard" ]; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "algo_config_wizard.py 파일을 찾을 수 없습니다."
        else
            echo "[ERROR] algo_config_wizard.py not found."
        fi
        return 1
    fi

    if type _ssafy_python_lookup >/dev/null 2>&1; then
        py_cmd=$(_ssafy_python_lookup)
    fi
    if [ -z "$py_cmd" ]; then
        py_cmd="python"
    fi

    "$py_cmd" "$wizard" || return 1
    _ssafy_algo_config_reload
    return 0
}

_ssafy_algo_config_show() {
    if type ui_panel_begin >/dev/null 2>&1; then
        ui_panel_begin "algo-config" "설정 요약 (version=${ALGO_FUNCTIONS_VERSION:-unknown})"
        ui_section "기본"
        ui_info "ALGO_BASE_DIR=${ALGO_BASE_DIR:-unset}"
        ui_section "IDE"
        ui_info "IDE_EDITOR=${IDE_EDITOR:-unset}"
        ui_section "Git"
        ui_info "GIT_DEFAULT_BRANCH=${GIT_DEFAULT_BRANCH:-main}"
        ui_info "GIT_COMMIT_PREFIX=${GIT_COMMIT_PREFIX:-solve}"
        ui_info "GIT_AUTO_PUSH=${GIT_AUTO_PUSH:-true}"
        ui_section "SSAFY"
        ui_info "SSAFY_BASE_URL=${SSAFY_BASE_URL:-https://lab.ssafy.com}"
        ui_info "SSAFY_USER_ID=${SSAFY_USER_ID:-unset}"
        if [ -n "${SSAFY_AUTH_TOKEN:-}" ]; then
            ui_info "SSAFY_AUTH_TOKEN=세션 전용(설정됨)"
        else
            ui_info "SSAFY_AUTH_TOKEN=세션 전용(미설정)"
        fi
        ui_hint "명령어: algo-config edit | algo-config reset | algo-config show"
        ui_panel_end
    elif type ui_header >/dev/null 2>&1; then
        ui_header "algo-config" "설정 요약 (version=${ALGO_FUNCTIONS_VERSION:-unknown})"
        ui_section "기본"
        ui_info "ALGO_BASE_DIR=${ALGO_BASE_DIR:-unset}"
        ui_section "IDE"
        ui_info "IDE_EDITOR=${IDE_EDITOR:-unset}"
        ui_section "Git"
        ui_info "GIT_DEFAULT_BRANCH=${GIT_DEFAULT_BRANCH:-main}"
        ui_info "GIT_COMMIT_PREFIX=${GIT_COMMIT_PREFIX:-solve}"
        ui_info "GIT_AUTO_PUSH=${GIT_AUTO_PUSH:-true}"
        ui_section "SSAFY"
        ui_info "SSAFY_BASE_URL=${SSAFY_BASE_URL:-https://lab.ssafy.com}"
        ui_info "SSAFY_USER_ID=${SSAFY_USER_ID:-unset}"
        if [ -n "${SSAFY_AUTH_TOKEN:-}" ]; then
            ui_info "SSAFY_AUTH_TOKEN=세션 전용(설정됨)"
        else
            ui_info "SSAFY_AUTH_TOKEN=세션 전용(미설정)"
        fi
        ui_hint "명령어: algo-config edit | algo-config reset | algo-config show"
    else
        echo "ALGO_BASE_DIR=${ALGO_BASE_DIR:-unset}"
        echo "IDE_EDITOR=${IDE_EDITOR:-unset}"
        echo "GIT_DEFAULT_BRANCH=${GIT_DEFAULT_BRANCH:-main}"
        echo "GIT_COMMIT_PREFIX=${GIT_COMMIT_PREFIX:-solve}"
        echo "GIT_AUTO_PUSH=${GIT_AUTO_PUSH:-true}"
        echo "SSAFY_BASE_URL=${SSAFY_BASE_URL:-https://lab.ssafy.com}"
        echo "SSAFY_USER_ID=${SSAFY_USER_ID:-unset}"
    fi
}

_ssafy_algo_config_cli_collect_value() {
    local key="$1"
    local current="$2"
    local out_var="$3"
    local value=""

    case "$key" in
        GIT_AUTO_PUSH)
            input_choice value "Select value for ${key}" "${current}" "true:true" "false:false"
            case $? in
                0) printf -v "$out_var" '%s' "$value"; return 0 ;;
                *) return $? ;;
            esac
            ;;
        ALGO_UI_STYLE)
            input_choice value "Select value for ${key}" "${current}" "panel:panel" "plain:plain"
            case $? in
                0) printf -v "$out_var" '%s' "$value"; return 0 ;;
                *) return $? ;;
            esac
            ;;
        ALGO_UI_COLOR)
            input_choice value "Select value for ${key}" "${current}" "auto:auto" "always:always" "never:never"
            case $? in
                0) printf -v "$out_var" '%s' "$value"; return 0 ;;
                *) return $? ;;
            esac
            ;;
        ALGO_INPUT_PROFILE)
            input_choice value "Select value for ${key}" "${current}" "stable:stable" "quick:quick" "strict:strict"
            case $? in
                0) printf -v "$out_var" '%s' "$value"; return 0 ;;
                *) return $? ;;
            esac
            ;;
        *)
            input_text value "Enter value for ${key}" "$current" true
            case $? in
                0) printf -v "$out_var" '%s' "$value"; return 0 ;;
                *) return $? ;;
            esac
            ;;
    esac
}

_ssafy_algo_config_cli_edit() {
    local key_choice=""
    local key=""
    local value=""
    local answer=""
    local rc=0
    local pending_keys=()
    local pending_values=()
    local i=0

    if ! _is_interactive || ! type input_choice >/dev/null 2>&1; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "CLI 편집은 대화형 터미널에서만 동작합니다."
        else
            echo "[ERROR] CLI edit needs interactive terminal."
        fi
        return 1
    fi

    while true; do
        input_choice key_choice "Select config key to edit" "done" \
            "ALGO_BASE_DIR:ALGO_BASE_DIR" \
            "IDE_EDITOR:IDE_EDITOR" \
            "GIT_DEFAULT_BRANCH:GIT_DEFAULT_BRANCH" \
            "GIT_COMMIT_PREFIX:GIT_COMMIT_PREFIX" \
            "GIT_AUTO_PUSH:GIT_AUTO_PUSH" \
            "SSAFY_BASE_URL:SSAFY_BASE_URL" \
            "SSAFY_USER_ID:SSAFY_USER_ID" \
            "SSAFY_UPDATE_CHANNEL:SSAFY_UPDATE_CHANNEL" \
            "ALGO_UI_STYLE:ALGO_UI_STYLE" \
            "ALGO_UI_COLOR:ALGO_UI_COLOR" \
            "ALGO_INPUT_PROFILE:ALGO_INPUT_PROFILE" \
            "done:Finish editing"
        rc=$?
        case "$rc" in
            20) return 1 ;;
            10) continue ;;
        esac

        if [ "$key_choice" = "done" ]; then
            break
        fi

        key="$key_choice"
        _ssafy_algo_config_cli_collect_value "$key" "$(_get_config_value "$key")" value
        rc=$?
        case "$rc" in
            20) return 1 ;;
            10) continue ;;
            0) ;;
            *) return 1 ;;
        esac

        pending_keys+=("$key")
        pending_values+=("$value")

        if type ui_ok >/dev/null 2>&1; then
            ui_ok "반영 대기: $key=$value"
        else
            echo "[OK] staged: $key=$value"
        fi
    done

    if [ "${#pending_keys[@]}" -eq 0 ]; then
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "변경할 항목이 없습니다."
        else
            echo "[WARN] No changes staged."
        fi
        return 0
    fi

    if type ui_header >/dev/null 2>&1; then
        ui_header "algo-config" "저장 전 변경 요약"
    fi
    for i in "${!pending_keys[@]}"; do
        echo "  - ${pending_keys[$i]}=${pending_values[$i]}"
    done

    input_confirm answer "Save these changes?" "y"
    case $? in
        20|10) return 1 ;;
    esac
    if [ "$answer" != "yes" ]; then
        return 1
    fi

    for i in "${!pending_keys[@]}"; do
        _set_config_value "${pending_keys[$i]}" "${pending_values[$i]}"
    done

    _ssafy_algo_config_reload
    if type ui_ok >/dev/null 2>&1; then
        ui_ok "설정이 저장되었습니다."
    else
        echo "[OK] Config updated."
    fi
    return 0
}

_ssafy_algo_config_reset() {
    local answer=""

    if _is_interactive && type input_confirm >/dev/null 2>&1; then
        input_confirm answer "Reset all config values?" "n"
        case $? in
            20|10) return 1 ;;
        esac
        [ "$answer" = "yes" ] || return 1

        input_confirm answer "Are you sure? This cannot be undone." "n"
        case $? in
            20|10) return 1 ;;
        esac
        [ "$answer" = "yes" ] || return 1
    fi

    rm -f "$ALGO_CONFIG_FILE"
    init_algo_config
    if type ui_ok >/dev/null 2>&1; then
        ui_ok "설정 초기화가 완료되었습니다."
    else
        echo "[OK] Config reset completed."
    fi
}

ssafy_algo_config() {
    init_algo_config

    case "${1:-show}" in
        show)
            _ssafy_algo_config_show
            return 0
            ;;
        edit)
            if _is_interactive && type input_choice >/dev/null 2>&1; then
                local edit_mode="gui"
                input_choice edit_mode "Select edit mode" "gui" \
                    "gui:GUI wizard (recommended)" \
                    "cli:CLI quick edit"
                case $? in
                    20|10) return 1 ;;
                esac

                if [ "$edit_mode" = "gui" ]; then
                    _ssafy_algo_config_run_gui || {
                        if type ui_warn >/dev/null 2>&1; then
                            ui_warn "GUI 마법사 실행에 실패해 CLI 편집으로 전환합니다."
                        else
                            echo "[WARN] GUI wizard failed. Switching to CLI edit."
                        fi
                        _ssafy_algo_config_cli_edit
                        return $?
                    }
                    return 0
                fi

                _ssafy_algo_config_cli_edit
                return $?
            fi

            _ssafy_algo_config_run_gui
            return $?
            ;;
        reset)
            _ssafy_algo_config_reset
            return $?
            ;;
        *)
            echo "Usage:"
            echo "  algo-config show"
            echo "  algo-config edit"
            echo "  algo-config reset"
            return 1
            ;;
    esac
}
