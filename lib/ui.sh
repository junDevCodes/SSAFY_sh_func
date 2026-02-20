# =============================================================================
# lib/ui.sh
# Shared UI helpers (panel/plain)
# =============================================================================

UI_PANEL_WIDTH_DEFAULT=72
UI_PANEL_WIDTH_MIN_DEFAULT=52
UI_PANEL_MARGIN_DEFAULT=4

UI_CLR_RESET=""
UI_CLR_INFO=""
UI_CLR_OK=""
UI_CLR_WARN=""
UI_CLR_ERR=""
UI_CLR_TITLE=""
UI_CLR_SECTION=""
UI_CLR_HINT=""

UI_PYTHON_CMD_CACHE=""
UI_PANEL_OPEN=0
UI_PANEL_OPEN_STYLE=""
UI_PANEL_FRAME_WIDTH=""

_ui_title_with_icon() {
    local title="$1"
    case "$title" in
        "SSAFY Algo Tools") printf '%s' "🧰 SSAFY Algo Tools" ;;
        "al") printf '%s' "🧩 al" ;;
        "gitup") printf '%s' "📥 gitup" ;;
        "gitdown") printf '%s' "📤 gitdown" ;;
        "algo-config") printf '%s' "🛠 algo-config" ;;
        "algo-update") printf '%s' "🔄 algo-update" ;;
        "algo-doctor") printf '%s' "🩺 algo-doctor" ;;
        *) printf '%s' "$title" ;;
    esac
}

_ui_prefix_icon() {
    local prefix="$1"
    case "$prefix" in
        "[INFO]") printf '%s' "ℹ" ;;
        "[OK]") printf '%s' "✅" ;;
        "[WARN]") printf '%s' "⚠" ;;
        "[ERROR]") printf '%s' "❌" ;;
        "[STEP]") printf '%s' "▶" ;;
        "[PATH]") printf '%s' "📁" ;;
        "[HINT]") printf '%s' "💡" ;;
        *) printf '%s' "•" ;;
    esac
}

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

_ui_renderer_mode() {
    local mode="${ALGO_UI_RENDERER:-auto}"
    case "$mode" in
        auto|python|plain) printf '%s' "$mode" ;;
        *) printf '%s' "auto" ;;
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

_ui_emoji_width_profile() {
    local mode="${ALGO_UI_EMOJI_WIDTH:-auto}"

    case "$mode" in
        narrow|wide)
            printf '%s' "$mode"
            return 0
            ;;
        auto|"")
            ;;
        *)
            mode="auto"
            ;;
    esac

    # VS Code + Git Bash 계열은 일부 이모지 폭을 1칸으로 렌더링하는 경우가 있어 narrow를 기본으로 사용한다.
    if [ "${TERM_PROGRAM:-}" = "vscode" ] || [ -n "${VSCODE_PID:-}" ] || [ -n "${VSCODE_GIT_IPC_HANDLE:-}" ] || [[ "${OSTYPE:-}" == msys* ]] || [ -n "${MSYSTEM:-}" ]; then
        printf '%s' "narrow"
    else
        printf '%s' "wide"
    fi
}

_ui_init_colors() {
    if _ui_use_color; then
        UI_CLR_RESET=$'\033[0m'
        UI_CLR_INFO=$'\033[96m'
        UI_CLR_OK=$'\033[92m'
        UI_CLR_WARN=$'\033[93m'
        UI_CLR_ERR=$'\033[91m'
        UI_CLR_TITLE=$'\033[1;96m'
        UI_CLR_SECTION=$'\033[1;33m'
        UI_CLR_HINT=$'\033[2;37m'
    else
        UI_CLR_RESET=""
        UI_CLR_INFO=""
        UI_CLR_OK=""
        UI_CLR_WARN=""
        UI_CLR_ERR=""
        UI_CLR_TITLE=""
        UI_CLR_SECTION=""
        UI_CLR_HINT=""
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

_ui_is_positive_int() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -gt 0 ]
}

_ui_is_non_negative_int() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]]
}

_ui_terminal_cols() {
    local cols=""
    local cols_env="${COLUMNS:-}"
    local cols_tput=""
    local cols_stty=""
    local stty_size=""
    local candidate=""

    if _ui_is_tty && command -v tput >/dev/null 2>&1; then
        cols_tput=$(tput cols 2>/dev/null || true)
    fi

    if _ui_is_tty && command -v stty >/dev/null 2>&1; then
        stty_size=$(stty size 2>/dev/null || true)
        cols_stty="${stty_size##* }"
    fi

    cols=$((UI_PANEL_WIDTH_DEFAULT + UI_PANEL_MARGIN_DEFAULT))

    for candidate in "$cols_env" "$cols_tput" "$cols_stty"; do
        if _ui_is_positive_int "$candidate" && [ "$candidate" -gt "$cols" ]; then
            cols="$candidate"
        fi
    done

    printf '%s' "$cols"
}

_ui_panel_width() {
    local width="${UI_PANEL_WIDTH:-}"
    local cols=""
    local margin="${ALGO_UI_PANEL_MARGIN:-$UI_PANEL_MARGIN_DEFAULT}"
    local min_width="${ALGO_UI_PANEL_MIN_WIDTH:-$UI_PANEL_WIDTH_MIN_DEFAULT}"
    local max_width="${ALGO_UI_PANEL_MAX_WIDTH:-0}"
    local safe_width=1

    if _ui_is_positive_int "$width"; then
        printf '%s' "$width"
        return 0
    fi

    cols=$(_ui_terminal_cols)

    if ! _ui_is_non_negative_int "$margin"; then
        margin="$UI_PANEL_MARGIN_DEFAULT"
    fi
    if ! _ui_is_positive_int "$min_width"; then
        min_width="$UI_PANEL_WIDTH_MIN_DEFAULT"
    fi
    if ! _ui_is_non_negative_int "$max_width"; then
        max_width=0
    fi

    # 패널 한 줄의 실제 길이는 (내부폭 + 4) 이므로, 창 경계 줄바꿈을 피하기 위해 4칸을 먼저 제외한다.
    safe_width=$((cols - margin - 4))
    if [ "$safe_width" -lt 1 ]; then
        safe_width=1
    fi

    # 최소폭은 가능한 경우에만 보장하고, 불가능한 좁은 창에서는 안전폭을 그대로 사용한다.
    if [ "$safe_width" -lt "$min_width" ] && [ "$cols" -ge "$((min_width + 4))" ]; then
        width="$min_width"
    else
        width="$safe_width"
    fi
    if [ "$max_width" -gt 0 ] && [ "$width" -gt "$max_width" ]; then
        width="$max_width"
    fi

    printf '%s' "$width"
}

_ui_frame_width() {
    local width_override="${1:-}"

    if _ui_is_positive_int "$width_override"; then
        printf '%s' "$width_override"
        return 0
    fi

    if [ "${UI_PANEL_OPEN:-0}" -eq 1 ] && _ui_is_positive_int "${UI_PANEL_FRAME_WIDTH:-}"; then
        printf '%s' "$UI_PANEL_FRAME_WIDTH"
        return 0
    fi

    _ui_panel_width
}

_ui_panel_border() {
    local width
    width=$(_ui_frame_width "${1:-}")
    printf '+%s+\n' "$(_ui_repeat_char "-" "$((width + 2))")"
}

_ui_panel_border_thin() {
    local width
    width=$(_ui_frame_width "${1:-}")
    printf '|%s|\n' "$(_ui_repeat_char "." "$((width + 2))")"
}

_ui_python_cmd_is_usable() {
    local cmd="$1"
    [ -n "$cmd" ] || return 1
    command -v "$cmd" >/dev/null 2>&1 || return 1
    "$cmd" -c "import sys; sys.exit(0)" >/dev/null 2>&1 || return 1
    return 0
}

_ui_python_cmd() {
    local candidate=""

    if [ -n "$UI_PYTHON_CMD_CACHE" ] && _ui_python_cmd_is_usable "$UI_PYTHON_CMD_CACHE"; then
        printf '%s' "$UI_PYTHON_CMD_CACHE"
        return 0
    fi

    if type _ssafy_python_lookup >/dev/null 2>&1; then
        candidate=$(_ssafy_python_lookup 2>/dev/null || true)
        if _ui_python_cmd_is_usable "$candidate"; then
            UI_PYTHON_CMD_CACHE="$candidate"
            printf '%s' "$UI_PYTHON_CMD_CACHE"
            return 0
        fi
    fi

    for candidate in python python3 py; do
        if _ui_python_cmd_is_usable "$candidate"; then
            UI_PYTHON_CMD_CACHE="$candidate"
            printf '%s' "$UI_PYTHON_CMD_CACHE"
            return 0
        fi
    done

    return 1
}

_ui_renderer_backend() {
    local style=""
    local mode=""

    style=$(_ui_style)
    if [ "$style" != "panel" ]; then
        printf '%s' "plain"
        return 0
    fi

    mode=$(_ui_renderer_mode)
    case "$mode" in
        plain)
            printf '%s' "plain"
            return 0
            ;;
        python|auto)
            if _ui_python_cmd >/dev/null 2>&1; then
                printf '%s' "python"
            else
                printf '%s' "plain"
            fi
            return 0
            ;;
    esac

    printf '%s' "plain"
}

_ui_effective_style() {
    local backend=""
    backend=$(_ui_renderer_backend)
    if [ "$backend" = "python" ]; then
        printf '%s' "panel"
    else
        printf '%s' "plain"
    fi
}

_ui_panel_line_python() {
    local text="$1"
    local width="$2"
    local py_cmd=""

    py_cmd=$(_ui_python_cmd) || return 1

    UI_PANEL_TEXT="$text" UI_EMOJI_WIDTH_PROFILE="$(_ui_emoji_width_profile)" PYTHONUTF8=1 PYTHONIOENCODING=UTF-8 "$py_cmd" - "$width" <<'PY'
import os
import sys
import unicodedata

width = int(sys.argv[1]) if len(sys.argv) > 1 else 72
text = os.environ.get("UI_PANEL_TEXT", "")
text = text.replace("\r", "").replace("\n", " ").replace("\t", "    ")
emoji_width_profile = os.environ.get("UI_EMOJI_WIDTH_PROFILE", "wide").strip().lower()
if emoji_width_profile not in ("narrow", "wide"):
    emoji_width_profile = "wide"

if width < 1:
    width = 1

EMOJI_WIDTH_OVERRIDES = {
    0x1F6E0: 1,  # 🛠 HAMMER AND WRENCH
}

def _base_width(ch: str) -> int:
    code = ord(ch)
    if code in (0x200D, 0xFE0E, 0xFE0F):
        return 0
    if unicodedata.combining(ch):
        return 0
    category = unicodedata.category(ch)
    if category in ("Mn", "Me", "Cf"):
        return 0
    if code in EMOJI_WIDTH_OVERRIDES:
        return EMOJI_WIDTH_OVERRIDES[code]
    if 0x1F1E6 <= code <= 0x1F1FF:
        return 2
    if emoji_width_profile == "wide" and 0x1F300 <= code <= 0x1FAFF:
        return 2
    if unicodedata.east_asian_width(ch) in ("W", "F"):
        return 2
    return 1

def _iter_clusters(s: str):
    i = 0
    n = len(s)
    while i < n:
        ch = s[i]
        code = ord(ch)
        if code in (0x200D, 0xFE0E, 0xFE0F) or unicodedata.combining(ch):
            yield ch, 0
            i += 1
            continue

        cluster = ch
        w = _base_width(ch)
        i += 1

        while i < n and ord(s[i]) in (0xFE0E, 0xFE0F):
            if ord(s[i]) == 0xFE0F and w < 2:
                w = 2
            cluster += s[i]
            i += 1

        while i + 1 < n and ord(s[i]) == 0x200D:
            cluster += s[i] + s[i + 1]
            w = max(w, 2)
            i += 2
            while i < n and ord(s[i]) in (0xFE0E, 0xFE0F):
                if ord(s[i]) == 0xFE0F and w < 2:
                    w = 2
                cluster += s[i]
                i += 1

        if w <= 0:
            w = 1
        yield cluster, w

def _disp_width(s: str) -> int:
    total = 0
    for _, w in _iter_clusters(s):
        total += w
    return total

def _split_by_width(s: str, maxw: int):
    out = []
    current = []
    used = 0
    for cluster, w in _iter_clusters(s):
        if w > maxw:
            cluster = "?"
            w = 1
        if current and (used + w) > maxw:
            out.append("".join(current))
            current = [cluster]
            used = w
        else:
            current.append(cluster)
            used += w
    if current or not out:
        out.append("".join(current))
    return out

def _wrap_line(s: str, maxw: int):
    i = 0
    while i < len(s) and s[i] == " ":
        i += 1
    indent = s[:i]
    body = s[i:]

    indent_w = _disp_width(indent)
    if indent_w >= maxw:
        indent = ""
        indent_w = 0

    available = max(1, maxw - indent_w)
    if not body:
        return [indent]

    words = [w for w in body.split(" ") if w != ""]
    if not words:
        return [indent]

    lines = []
    current = ""
    current_w = 0

    for word in words:
        word_w = _disp_width(word)
        if not current:
            if word_w <= available:
                current = word
                current_w = word_w
            else:
                parts = _split_by_width(word, available)
                if len(parts) > 1:
                    lines.extend(indent + p for p in parts[:-1])
                current = parts[-1]
                current_w = _disp_width(current)
        else:
            if current_w + 1 + word_w <= available:
                current += " " + word
                current_w += 1 + word_w
            else:
                lines.append(indent + current)
                if word_w <= available:
                    current = word
                    current_w = word_w
                else:
                    parts = _split_by_width(word, available)
                    if len(parts) > 1:
                        lines.extend(indent + p for p in parts[:-1])
                    current = parts[-1]
                    current_w = _disp_width(current)

    if current or not lines:
        lines.append(indent + current)
    return lines

def emit(line):
    used_width = _disp_width(line)
    pad = max(0, width - used_width)
    sys.stdout.write("| " + line + (" " * pad) + " |\n")

if not text:
    emit("")
    sys.exit(0)

for wrapped in _wrap_line(text, width):
    emit(wrapped)
PY
}

_ui_panel_line() {
    local text="$1"
    local width
    width=$(_ui_frame_width "${2:-}")
    text="${text//$'\n'/ }"
    if ! _ui_panel_line_python "$text" "$width" 2>/dev/null; then
        printf '| %-*.*s |\n' "$width" "$width" "$text"
    fi
}

ui_divider() {
    local char="${1:--}"
    local width
    width=$(_ui_panel_width)
    _ui_repeat_char "$char" "$((width + 4))"
    printf '\n'
}

ui_panel_begin() {
    local title="$1"
    local subtitle="${2:-}"
    local title_view=""
    local style=""
    local frame_width=""

    _ui_init_colors
    title_view=$(_ui_title_with_icon "$title")
    style=$(_ui_effective_style)
    frame_width=$(_ui_panel_width)

    UI_PANEL_OPEN=1
    UI_PANEL_OPEN_STYLE="$style"
    UI_PANEL_FRAME_WIDTH="$frame_width"

    if [ "$style" = "panel" ]; then
        _ui_panel_border "$frame_width"
        _ui_panel_line "$title_view" "$frame_width" || printf '%s\n' "$title_view"
        if [ -n "$subtitle" ]; then
            _ui_panel_line "$subtitle" "$frame_width" || printf '%s\n' "$subtitle"
        fi
    else
        printf '%s%s%s\n' "$UI_CLR_TITLE" "$title_view" "$UI_CLR_RESET"
        if [ -n "$subtitle" ]; then
            printf '%s\n' "$subtitle"
        fi
        ui_divider
    fi
}

ui_panel_end() {
    local frame_width="${UI_PANEL_FRAME_WIDTH:-}"

    if [ "${UI_PANEL_OPEN:-0}" -ne 1 ]; then
        return 0
    fi

    if ! _ui_is_positive_int "$frame_width"; then
        frame_width=$(_ui_panel_width)
    fi

    if [ "$UI_PANEL_OPEN_STYLE" = "panel" ]; then
        _ui_panel_border "$frame_width"
    else
        ui_divider
    fi

    UI_PANEL_OPEN=0
    UI_PANEL_OPEN_STYLE=""
    UI_PANEL_FRAME_WIDTH=""
}

ui_panel_is_open() {
    [ "${UI_PANEL_OPEN:-0}" -eq 1 ]
}

ui_header() {
    local title="$1"
    local subtitle="${2:-}"
    local title_view=""
    local style=""
    local frame_width=""

    _ui_init_colors
    title_view=$(_ui_title_with_icon "$title")
    style=$(_ui_effective_style)
    frame_width=$(_ui_panel_width)

    if [ "$style" = "panel" ]; then
        _ui_panel_border "$frame_width"
        _ui_panel_line "$title_view" "$frame_width" || printf '%s\n' "$title_view"
        if [ -n "$subtitle" ]; then
            _ui_panel_line "$subtitle" "$frame_width" || printf '%s\n' "$subtitle"
        fi
        _ui_panel_border "$frame_width"
    else
        printf '%s%s%s\n' "$UI_CLR_TITLE" "$title_view" "$UI_CLR_RESET"
        if [ -n "$subtitle" ]; then
            printf '%s\n' "$subtitle"
        fi
        ui_divider
    fi
}

ui_section() {
    local title="$1"
    local style=""
    local frame_width=""

    _ui_init_colors
    style=$(_ui_effective_style)
    frame_width=$(_ui_frame_width)

    if ui_panel_is_open && [ "$UI_PANEL_OPEN_STYLE" = "panel" ]; then
        _ui_panel_border_thin "$frame_width"
        _ui_panel_line "📌 [$title]" "$frame_width" || printf '\n📌 [%s]\n' "$title"
        return 0
    fi

    if [ "$style" = "panel" ]; then
        _ui_panel_line "📌 [$title]" "$frame_width" || printf '\n📌 [%s]\n' "$title"
    else
        printf '\n%s📌 [%s]%s\n' "$UI_CLR_SECTION" "$title" "$UI_CLR_RESET"
    fi
}

_ui_print_with_prefix() {
    local color="$1"
    local prefix="$2"
    local message="$3"
    local icon=""
    local frame_width=""

    _ui_init_colors
    icon=$(_ui_prefix_icon "$prefix")
    frame_width=$(_ui_frame_width)

    if ui_panel_is_open && [ "$UI_PANEL_OPEN_STYLE" = "panel" ]; then
        _ui_panel_line "  ${icon} ${prefix} ${message}" "$frame_width" || printf '  %s %s %s\n' "$icon" "$prefix" "$message"
        return 0
    fi

    printf '  %s%s %s%s %s\n' "$color" "$icon" "$prefix" "$UI_CLR_RESET" "$message"
}

ui_info()  { _ui_print_with_prefix "$UI_CLR_INFO"  "[INFO]"  "$1"; }
ui_ok()    { _ui_print_with_prefix "$UI_CLR_OK"    "[OK]"    "$1"; }
ui_warn()  { _ui_print_with_prefix "$UI_CLR_WARN"  "[WARN]"  "$1"; }
ui_error() { _ui_print_with_prefix "$UI_CLR_ERR"   "[ERROR]" "$1"; }
ui_step()  { _ui_print_with_prefix "$UI_CLR_INFO"  "[STEP]"  "$1"; }
ui_path()  { _ui_print_with_prefix "$UI_CLR_INFO"  "[PATH]"  "$1"; }
ui_hint()  { _ui_print_with_prefix "$UI_CLR_HINT"  "[HINT]"  "$1"; }
