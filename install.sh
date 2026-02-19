#!/bin/bash
# =============================================================================
# SSAFY Shell Functions installer
# =============================================================================
set -e

INSTALL_DIR="$HOME/.ssafy-tools"
INSTALL_META_FILE=".install_meta"

REPO_OWNER="${SSAFY_REPO_OWNER:-junDevCodes}"
REPO_NAME="${SSAFY_REPO_NAME:-SSAFY_sh_func}"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
RELEASE_API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"

INSTALL_MODE="${SSAFY_INSTALL_MODE:-snapshot}"
UPDATE_CHANNEL="${SSAFY_UPDATE_CHANNEL:-stable}"

RUN_SETUP=false
INSTALLED_VERSION="Unknown"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

read_version_from_dir() {
    local target_dir="$1"
    local version_file="$target_dir/VERSION"
    local version="Unknown"

    if [ -f "$version_file" ]; then
        read -r version < "$version_file" || true
        version="${version//$'\r'/}"
        version="${version//[[:space:]]/}"
    fi

    printf '%s' "$version"
}

normalize_install_mode() {
    case "$INSTALL_MODE" in
        snapshot|git) ;;
        *)
            echo "[warn] Unknown INSTALL_MODE=$INSTALL_MODE. Fallback to snapshot."
            INSTALL_MODE="snapshot"
            ;;
    esac
}

normalize_update_channel() {
    case "$UPDATE_CHANNEL" in
        stable|main|edge) ;;
        *)
            echo "[warn] Unknown UPDATE_CHANNEL=$UPDATE_CHANNEL. Fallback to stable."
            UPDATE_CHANNEL="stable"
            ;;
    esac
}

fetch_latest_release_tag() {
    local response=""
    local tag=""

    if ! command_exists curl; then
        return 1
    fi

    response=$(curl -fsSL "$RELEASE_API_URL" 2>/dev/null || true)
    if [ -z "$response" ]; then
        return 1
    fi

    tag=$(printf '%s\n' "$response" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
    if [ -z "$tag" ]; then
        return 1
    fi

    printf '%s' "$tag"
    return 0
}

build_tarball_url() {
    local ref="$1"
    if [ "$ref" = "main" ]; then
        printf 'https://github.com/%s/%s/archive/refs/heads/main.tar.gz' "$REPO_OWNER" "$REPO_NAME"
    else
        printf 'https://github.com/%s/%s/archive/refs/tags/%s.tar.gz' "$REPO_OWNER" "$REPO_NAME" "$ref"
    fi
}

sha256_of_file() {
    local file="$1"

    if command_exists sha256sum; then
        sha256sum "$file" | awk '{print $1}'
        return 0
    fi

    if command_exists shasum; then
        shasum -a 256 "$file" | awk '{print $1}'
        return 0
    fi

    return 1
}

verify_tarball_checksum() {
    local archive_file="$1"
    local tarball_url="$2"
    local checksum_file="$3"
    local expected=""
    local actual=""

    if ! actual=$(sha256_of_file "$archive_file"); then
        echo "[warn] sha256 tool missing. Skip checksum verification."
        return 0
    fi

    if [ -n "${SSAFY_TARBALL_SHA256:-}" ]; then
        if [ "$actual" != "$SSAFY_TARBALL_SHA256" ]; then
            echo "[error] Tarball checksum mismatch."
            return 1
        fi
        return 0
    fi

    if command_exists curl && curl -fsSL "${tarball_url}.sha256" -o "$checksum_file" 2>/dev/null; then
        expected=$(awk 'NF>0 {print $1; exit}' "$checksum_file")
        if [ -n "$expected" ] && [ "$actual" = "$expected" ]; then
            return 0
        fi
        echo "[error] Remote checksum verification failed."
        return 1
    fi

    echo "[warn] No remote checksum file. Continue without remote checksum."
    return 0
}

resolve_snapshot_ref() {
    local ref=""

    if [ -n "${SSAFY_INSTALL_REF:-}" ]; then
        printf '%s' "$SSAFY_INSTALL_REF"
        return 0
    fi

    if [ "$UPDATE_CHANNEL" = "stable" ]; then
        ref=$(fetch_latest_release_tag || true)
        if [ -n "$ref" ]; then
            printf '%s' "$ref"
            return 0
        fi
        echo "[warn] Failed to fetch latest release tag. Fallback to main snapshot."
        printf '%s' "main"
        return 0
    fi

    printf '%s' "main"
}

write_install_meta() {
    local mode="$1"
    local channel="$2"
    local ref="$3"
    local version="$4"
    local installed_at=""

    installed_at=$(date +"%Y-%m-%dT%H:%M:%S%z")
    cat > "$INSTALL_DIR/$INSTALL_META_FILE" <<EOF
mode=$mode
channel=$channel
ref=$ref
version=$version
installed_at=$installed_at
EOF
}

install_snapshot() {
    local ref=""
    local tarball_url=""
    local tmp_dir=""
    local archive_file=""
    local checksum_file=""

    if ! command_exists curl; then
        echo "[error] snapshot mode requires curl."
        return 1
    fi

    if ! command_exists tar; then
        echo "[error] snapshot mode requires tar."
        return 1
    fi

    ref=$(resolve_snapshot_ref)
    tarball_url=$(build_tarball_url "$ref")

    tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t ssafy_tools_install)
    archive_file="$tmp_dir/repo.tar.gz"
    checksum_file="$tmp_dir/repo.tar.gz.sha256"
    trap 'rm -rf "$tmp_dir"' RETURN

    echo "Downloading snapshot... (ref: $ref)"
    if ! curl -fsSL "$tarball_url" -o "$archive_file"; then
        if [ "$ref" != "main" ]; then
            echo "[warn] Failed to download ref tarball. Retrying with main."
            ref="main"
            tarball_url=$(build_tarball_url "$ref")
            curl -fsSL "$tarball_url" -o "$archive_file" || {
                echo "[error] Snapshot download failed."
                return 1
            }
        else
            echo "[error] Snapshot download failed."
            return 1
        fi
    fi

    verify_tarball_checksum "$archive_file" "$tarball_url" "$checksum_file" || return 1

    mkdir -p "$INSTALL_DIR"
    if ! tar -xzf "$archive_file" -C "$INSTALL_DIR" --strip-components=1; then
        echo "[error] Snapshot extraction failed."
        return 1
    fi

    if [ -d "$INSTALL_DIR/.git" ]; then
        echo "[warn] Unexpected .git found in snapshot install. Removing it."
        rm -rf "$INSTALL_DIR/.git"
    fi

    INSTALLED_VERSION=$(read_version_from_dir "$INSTALL_DIR")
    write_install_meta "snapshot" "$UPDATE_CHANNEL" "$ref" "$INSTALLED_VERSION"

    trap - RETURN
    rm -rf "$tmp_dir"
}

install_git_mode() {
    local ref="${SSAFY_INSTALL_REF:-main}"

    if ! command_exists git; then
        echo "[error] git mode requires git."
        return 1
    fi

    echo "Running git clone... (ref: $ref)"
    if ! git clone --depth 1 --branch "$ref" "$REPO_URL" "$INSTALL_DIR"; then
        echo "[warn] Failed to clone requested ref. Retrying default clone."
        git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" || {
            echo "[error] Repository clone failed."
            return 1
        }
        ref="main"
    fi

    INSTALLED_VERSION=$(read_version_from_dir "$INSTALL_DIR")
    write_install_meta "git" "$UPDATE_CHANNEL" "$ref" "$INSTALLED_VERSION"
}

cleanup_old_install() {
    local rc_file="$1"

    if [ -f "$rc_file" ]; then
        local tmp_file="${rc_file}.tmp"
        sed '/ssafy-tools\/algo_functions\.sh/d' "$rc_file" | \
        sed '/SSAFY_sh_func\/algo_functions\.sh/d' > "$tmp_file"
        mv "$tmp_file" "$rc_file"
    fi
}

add_source_line() {
    local rc_file="$1"
    local source_line="source \"$INSTALL_DIR/algo_functions.sh\""

    if [ ! -f "$rc_file" ]; then
        touch "$rc_file"
        echo "   Created config file: $rc_file"
    fi

    cleanup_old_install "$rc_file"

    if grep -q "ssafy-tools/algo_functions.sh" "$rc_file"; then
        echo "   Source line already exists in $rc_file"
    else
        if [ -s "$rc_file" ]; then
            echo "" >> "$rc_file"
        fi

        echo "# SSAFY Shell Functions" >> "$rc_file"
        if [ -n "${detected_python:-}" ]; then
            echo "export SSAFY_PYTHON=\"$detected_python\"" >> "$rc_file"
            echo "alias python=\"\$SSAFY_PYTHON\"" >> "$rc_file"
        fi
        echo "$source_line" >> "$rc_file"
        echo "   Added source line to $rc_file"
    fi
}

ensure_bashrc_sourced() {
    local profile="$1"

    if [ ! -f "$profile" ]; then
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
            echo "if [ -f ~/.bashrc ]; then . ~/.bashrc; fi" > "$profile"
            echo "   Created $profile"
        fi
    else
        if ! grep -q ".bashrc" "$profile"; then
            echo "" >> "$profile"
            echo "# Load .bashrc if it exists" >> "$profile"
            echo "if [ -f ~/.bashrc ]; then . ~/.bashrc; fi" >> "$profile"
            echo "   Added .bashrc loader to $profile"
        fi
    fi
}

normalize_install_mode
normalize_update_channel

echo ""
echo "Starting SSAFY Shell Functions installer."
echo "Install mode: $INSTALL_MODE / Update channel: $UPDATE_CHANNEL"
echo ""

if [ -d "$INSTALL_DIR" ]; then
    echo "[warn] Existing installation detected: $INSTALL_DIR"
    read -r -p "Remove existing installation and continue? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        echo "Removed previous installation."
    else
        echo "Installation cancelled."
        exit 1
    fi
fi

echo "Preparing installation files..."
if [ "$INSTALL_MODE" = "git" ]; then
    install_git_mode || exit 1
else
    install_snapshot || exit 1
fi

echo ""
echo "Updating shell profiles..."
add_source_line "$HOME/.bashrc"
ensure_bashrc_sourced "$HOME/.bash_profile"
if [ ! -f "$HOME/.bash_profile" ]; then
    ensure_bashrc_sourced "$HOME/.profile"
fi

if [ -f "$HOME/.zshrc" ]; then
    add_source_line "$HOME/.zshrc"
fi

if [ -f "$HOME/.algo_config" ]; then
    echo ""
    echo "[warn] Existing user config found: ~/.algo_config"
    read -r -p "Reset config now? (recommended on new PC) (y/N): " reset_config
    if [[ "$reset_config" =~ ^[Yy]$ ]]; then
        rm "$HOME/.algo_config"
        RUN_SETUP=true
        echo "Config reset completed."
    else
        echo "Keeping existing config."
    fi
else
    RUN_SETUP=true
fi

echo ""
echo "============================================================"
echo "Installation completed. (version: ${INSTALLED_VERSION})"
echo "============================================================"
echo ""
echo "Run this to start now:"
echo "   source ~/.bashrc"
echo ""
echo "Main commands"
echo "   - gitup <URL>          : clone repository and open files"
echo "   - gitdown              : commit and push"
echo "   - algo-config show     : show config"
echo "   - algo-config edit     : edit config"
echo "   - algo-update          : update to latest"
echo ""
echo "Guide: https://github.com/junDevCodes/SSAFY_sh_func"
echo ""

if [ "$RUN_SETUP" = true ]; then
    echo "Starting initial config..."
    echo ""

    CONFIG_FILE="$HOME/.algo_config"
    cat > "$CONFIG_FILE" << 'EOF'
# SSAFY Algo Functions Config
ALGO_BASE_DIR="$HOME/algos"
GIT_DEFAULT_BRANCH="main"
GIT_COMMIT_PREFIX="solve"
GIT_AUTO_PUSH=true
IDE_EDITOR=""
SSAFY_BASE_URL="https://lab.ssafy.com"
SSAFY_USER_ID=""
# Token is not persisted to file for security (session-only)
EOF

    read -r -p "SSAFY GitLab username (lab.ssafy.com/{here}): " ssafy_user
    if [ -n "$ssafy_user" ]; then
        sed -i "s/SSAFY_USER_ID=\"\"/SSAFY_USER_ID=\"$ssafy_user\"/" "$CONFIG_FILE"
    fi

    echo ""
    echo "Initial config completed."
    echo "Token input is prompted automatically when running gitup."
    echo ""
    read -r -p "Press Enter to apply settings..." _
    exec bash
fi
