# =============================================================================
# lib/ui.sh
# Shared UI helpers (panel/plain)
# =============================================================================

UI_PANEL_WIDTH_DEFAULT=60
UI_CLR_RESET=""
UI_CLR_INFO=""
UI_CLR_OK=""
UI_CLR_WARN=""
UI_CLR_ERR=""
UI_CLR_TITLE=""

_ui_is_tty() {
    [ -t 1 ]
}

_ui_style() {
    local style="${ALGO_UI_STYLE:-panel}"
    case "$style" in
        panel|plain) printf '%s' "$style" ;;
        *) printf '%s' "panel" ;;
    esac
}

_ui_color_mode() {
    local mode="${ALGO_UI_COLOR:-auto}"
    case "$mode" in
        auto|always|never) printf '%s' "$mode" ;;
        *) printf '%s' "auto" ;;
    esac
}

_ui_use_color() {
    local mode
    mode=$(_ui_color_mode)

    if [ -n "${NO_COLOR:-}" ]; then
        return 1
    fi

    case "$mode" in
        always) return 0 ;;
        never) return 1 ;;
        auto)
            _ui_is_tty
            return $?
            ;;
    esac

    return 1
}

_ui_init_colors() {
    if _ui_use_color; then
        UI_CLR_RESET=$'\033[0m'
        UI_CLR_INFO=$'\033[36m'
        UI_CLR_OK=$'\033[32m'
        UI_CLR_WARN=$'\033[33m'
        UI_CLR_ERR=$'\033[31m'
        UI_CLR_TITLE=$'\033[1;37m'
    else
        UI_CLR_RESET=""
        UI_CLR_INFO=""
        UI_CLR_OK=""
        UI_CLR_WARN=""
        UI_CLR_ERR=""
        UI_CLR_TITLE=""
    fi
}

_ui_repeat_char() {
    local char="$1"
    local count="$2"
    local out=""
    local i=0
    while [ "$i" -lt "$count" ]; do
        out="${out}${char}"
        i=$((i + 1))
    done
    printf '%s' "$out"
}

_ui_panel_width() {
    local width="${UI_PANEL_WIDTH:-$UI_PANEL_WIDTH_DEFAULT}"
    if ! [[ "$width" =~ ^[0-9]+$ ]]; then
        width="$UI_PANEL_WIDTH_DEFAULT"
    fi
    if [ "$width" -lt 30 ]; then
        width=30
    fi
    printf '%s' "$width"
}

_ui_panel_border() {
    local width
    width=$(_ui_panel_width)
    printf '+%s+\n' "$(_ui_repeat_char "-" "$width")"
}

_ui_trim_to_width() {
    local text="$1"
    local width="$2"
    if [ "${#text}" -gt "$width" ]; then
        printf '%s' "${text:0:$width}"
    else
        printf '%s' "$text"
    fi
}

_ui_panel_line() {
    local text="$1"
    local width
    width=$(_ui_panel_width)
    text="${text//$'\n'/ }"
    text=$(_ui_trim_to_width "$text" "$width")
    printf '| %-*s |\n' "$width" "$text"
}

ui_divider() {
    local char="${1:--}"
    local width
    width=$(_ui_panel_width)
    _ui_repeat_char "$char" "$((width + 4))"
    printf '\n'
}

ui_header() {
    local title="$1"
    local subtitle="${2:-}"
    _ui_init_colors

    if [ "$(_ui_style)" = "panel" ]; then
        _ui_panel_border
        _ui_panel_line "${UI_CLR_TITLE}${title}${UI_CLR_RESET}"
        if [ -n "$subtitle" ]; then
            _ui_panel_line "$subtitle"
        fi
        _ui_panel_border
    else
        printf '%s%s%s\n' "$UI_CLR_TITLE" "$title" "$UI_CLR_RESET"
        if [ -n "$subtitle" ]; then
            printf '%s\n' "$subtitle"
        fi
        ui_divider
    fi
}

ui_section() {
    local title="$1"
    _ui_init_colors
    if [ "$(_ui_style)" = "panel" ]; then
        _ui_panel_line "[$title]"
    else
        printf '\n[%s]\n' "$title"
    fi
}

_ui_print_with_prefix() {
    local color="$1"
    local prefix="$2"
    local message="$3"
    _ui_init_colors

    if [ "$(_ui_style)" = "panel" ]; then
        _ui_panel_line "${color}${prefix}${UI_CLR_RESET} ${message}"
    else
        printf '%s%s%s %s\n' "$color" "$prefix" "$UI_CLR_RESET" "$message"
    fi
}

ui_info()  { _ui_print_with_prefix "$UI_CLR_INFO"  "[INFO]"  "$1"; }
ui_ok()    { _ui_print_with_prefix "$UI_CLR_OK"    "[OK]"    "$1"; }
ui_warn()  { _ui_print_with_prefix "$UI_CLR_WARN"  "[WARN]"  "$1"; }
ui_error() { _ui_print_with_prefix "$UI_CLR_ERR"   "[ERROR]" "$1"; }
ui_step()  { _ui_print_with_prefix "$UI_CLR_INFO"  "[STEP]"  "$1"; }
ui_path()  { _ui_print_with_prefix "$UI_CLR_INFO"  "[PATH]"  "$1"; }
ui_hint()  { _ui_print_with_prefix "$UI_CLR_WARN"  "[HINT]"  "$1"; }
