# =============================================================================
# lib/input.sh
# Shared input helpers with stable flow controls
# return codes: 0=ok, 10=back, 20=cancel
# =============================================================================

INPUT_RC_OK=0
INPUT_RC_BACK=10
INPUT_RC_CANCEL=20

_input_is_interactive() {
    if type _is_interactive >/dev/null 2>&1; then
        _is_interactive
        return $?
    fi
    [ -t 0 ] && [ -t 1 ]
}

_input_trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

_input_handle_nav_key() {
    local value="$1"
    case "$value" in
        q|Q) return "$INPUT_RC_CANCEL" ;;
        b|B) return "$INPUT_RC_BACK" ;;
    esac
    return "$INPUT_RC_OK"
}

input_text() {
    local out_var="$1"
    local prompt="$2"
    local default_value="${3:-}"
    local allow_empty="${4:-false}"
    local value=""
    local display_prompt="$prompt"

    if ! _input_is_interactive; then
        if [ -n "$default_value" ] || [ "$allow_empty" = "true" ]; then
            printf -v "$out_var" '%s' "$default_value"
            return "$INPUT_RC_OK"
        fi
        return 1
    fi

    while true; do
        display_prompt="$prompt"
        if [ -n "$default_value" ]; then
            display_prompt="${display_prompt} [default: ${default_value}]"
        fi
        display_prompt="${display_prompt} (q=cancel, b=back): "

        read -r -p "$display_prompt" value
        value="${value//$'\r'/}"

        _input_handle_nav_key "$value"
        case $? in
            "$INPUT_RC_BACK") return "$INPUT_RC_BACK" ;;
            "$INPUT_RC_CANCEL") return "$INPUT_RC_CANCEL" ;;
        esac

        if [ -z "$value" ] && [ -n "$default_value" ]; then
            value="$default_value"
        fi

        if [ -z "$value" ] && [ "$allow_empty" != "true" ]; then
            if type ui_warn >/dev/null 2>&1; then
                ui_warn "Empty value is not allowed."
            else
                echo "[WARN] Empty value is not allowed."
            fi
            continue
        fi

        printf -v "$out_var" '%s' "$value"
        return "$INPUT_RC_OK"
    done
}

input_choice() {
    local out_var="$1"
    local prompt="$2"
    local default_key="$3"
    shift 3
    local entries=("$@")
    local choice=""
    local valid=false
    local key=""
    local label=""
    local line=""

    if ! _input_is_interactive; then
        if [ -n "$default_key" ]; then
            printf -v "$out_var" '%s' "$default_key"
            return "$INPUT_RC_OK"
        fi
        return 1
    fi

    if [ "${#entries[@]}" -eq 0 ]; then
        return 1
    fi

    while true; do
        if type ui_section >/dev/null 2>&1; then
            ui_section "$prompt"
        else
            echo "[$prompt]"
        fi

        for line in "${entries[@]}"; do
            key="${line%%:*}"
            label="${line#*:}"
            echo "  $key) $label"
        done

        read -r -p "Select [default: ${default_key}] (q=cancel, b=back): " choice
        choice="${choice//$'\r'/}"

        _input_handle_nav_key "$choice"
        case $? in
            "$INPUT_RC_BACK") return "$INPUT_RC_BACK" ;;
            "$INPUT_RC_CANCEL") return "$INPUT_RC_CANCEL" ;;
        esac

        if [ -z "$choice" ]; then
            choice="$default_key"
        fi

        valid=false
        for line in "${entries[@]}"; do
            key="${line%%:*}"
            if [ "$choice" = "$key" ]; then
                valid=true
                break
            fi
        done

        if [ "$valid" = true ]; then
            printf -v "$out_var" '%s' "$choice"
            return "$INPUT_RC_OK"
        fi

        if type ui_warn >/dev/null 2>&1; then
            ui_warn "Invalid choice: $choice"
        else
            echo "[WARN] Invalid choice: $choice"
        fi
    done
}

input_confirm() {
    local out_var="$1"
    local prompt="$2"
    local default_value="${3:-n}"
    local answer=""
    local normalized_default="n"
    local default_mark="N"

    case "$default_value" in
        y|Y|yes|YES)
            normalized_default="y"
            default_mark="Y"
            ;;
        *)
            normalized_default="n"
            default_mark="N"
            ;;
    esac

    if ! _input_is_interactive; then
        if [ "$normalized_default" = "y" ]; then
            printf -v "$out_var" '%s' "yes"
        else
            printf -v "$out_var" '%s' "no"
        fi
        return "$INPUT_RC_OK"
    fi

    while true; do
        read -r -p "${prompt} (y/n, default=${default_mark}, q=cancel, b=back): " answer
        answer="${answer//$'\r'/}"

        _input_handle_nav_key "$answer"
        case $? in
            "$INPUT_RC_BACK") return "$INPUT_RC_BACK" ;;
            "$INPUT_RC_CANCEL") return "$INPUT_RC_CANCEL" ;;
        esac

        answer=$(_input_trim "$answer")
        if [ -z "$answer" ]; then
            answer="$normalized_default"
        fi

        case "$answer" in
            y|Y|yes|YES)
                printf -v "$out_var" '%s' "yes"
                return "$INPUT_RC_OK"
                ;;
            n|N|no|NO)
                printf -v "$out_var" '%s' "no"
                return "$INPUT_RC_OK"
                ;;
            *)
                if type ui_warn >/dev/null 2>&1; then
                    ui_warn "Please answer with y or n."
                else
                    echo "[WARN] Please answer with y or n."
                fi
                ;;
        esac
    done
}

input_masked() {
    local out_var="$1"
    local prompt="$2"
    local value=""

    if ! _input_is_interactive; then
        return 1
    fi

    if type _read_masked_input >/dev/null 2>&1; then
        value=$(_read_masked_input "$prompt")
        echo "" >&2
    else
        read -r -s -p "$prompt" value
        echo ""
    fi

    value="${value//$'\r'/}"

    _input_handle_nav_key "$value"
    case $? in
        "$INPUT_RC_BACK") return "$INPUT_RC_BACK" ;;
        "$INPUT_RC_CANCEL") return "$INPUT_RC_CANCEL" ;;
    esac

    printf -v "$out_var" '%s' "$value"
    return "$INPUT_RC_OK"
}
