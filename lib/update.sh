# =============================================================================
# lib/update.sh
# Update and version check logic
# =============================================================================

SSAFY_INSTALL_META_FILE=".install_meta"
ALGO_UPDATE_CHECK_FILE="$HOME/.algo_update_last_check"

_ssafy_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

_ssafy_repo_owner() {
    printf '%s' "${SSAFY_REPO_OWNER:-junDevCodes}"
}

_ssafy_repo_name() {
    printf '%s' "${SSAFY_REPO_NAME:-SSAFY_sh_func}"
}

_ssafy_release_api_url() {
    printf 'https://api.github.com/repos/%s/%s/releases/latest' "$(_ssafy_repo_owner)" "$(_ssafy_repo_name)"
}

_ssafy_build_tarball_url() {
    local ref="$1"
    if [ "$ref" = "main" ]; then
        printf 'https://github.com/%s/%s/archive/refs/heads/main.tar.gz' "$(_ssafy_repo_owner)" "$(_ssafy_repo_name)"
    else
        printf 'https://github.com/%s/%s/archive/refs/tags/%s.tar.gz' "$(_ssafy_repo_owner)" "$(_ssafy_repo_name)" "$ref"
    fi
}

_ssafy_read_meta_value() {
    local script_dir="$1"
    local key="$2"
    local meta_file="$script_dir/$SSAFY_INSTALL_META_FILE"

    if [ ! -f "$meta_file" ]; then
        return 1
    fi

    grep -E "^${key}=" "$meta_file" | tail -n 1 | cut -d'=' -f2- | tr -d '\r'
}

_ssafy_read_version_from_dir() {
    local script_dir="$1"
    local version_file="$script_dir/VERSION"
    local version="Unknown"

    if [ -f "$version_file" ]; then
        read -r version < "$version_file" || true
        version="${version//$'\r'/}"
        version="${version//[[:space:]]/}"
    fi

    printf '%s' "$version"
}

_ssafy_resolve_update_channel() {
    local script_dir="$1"
    local channel=""

    if [ -n "${SSAFY_UPDATE_CHANNEL:-}" ]; then
        channel="$SSAFY_UPDATE_CHANNEL"
    else
        channel=$(_ssafy_read_meta_value "$script_dir" "channel" 2>/dev/null || true)
    fi

    case "$channel" in
        stable|main|edge) printf '%s' "$channel" ;;
        *) printf '%s' "stable" ;;
    esac
}

_ssafy_resolve_install_mode() {
    local script_dir="$1"
    local mode=""

    if [ -n "${SSAFY_INSTALL_MODE:-}" ]; then
        mode="$SSAFY_INSTALL_MODE"
    else
        mode=$(_ssafy_read_meta_value "$script_dir" "mode" 2>/dev/null || true)
    fi

    case "$mode" in
        git|snapshot)
            printf '%s' "$mode"
            return 0
            ;;
    esac

    if [ -d "$script_dir/.git" ]; then
        printf '%s' "legacy-git"
    else
        printf '%s' "snapshot"
    fi
}

_ssafy_fetch_latest_release_tag() {
    local response=""
    local tag=""

    if ! _ssafy_command_exists curl; then
        return 1
    fi

    response=$(curl -fsSL "$(_ssafy_release_api_url)" 2>/dev/null || true)
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

_ssafy_resolve_snapshot_ref() {
    local channel="$1"
    local ref=""

    if [ -n "${SSAFY_INSTALL_REF:-}" ]; then
        printf '%s' "$SSAFY_INSTALL_REF"
        return 0
    fi

    if [ "$channel" = "stable" ]; then
        ref=$(_ssafy_fetch_latest_release_tag || true)
        if [ -n "$ref" ]; then
            printf '%s' "$ref"
            return 0
        fi
        echo "[warn] Failed to fetch latest release tag. Fallback to main snapshot." >&2
        printf '%s' "main"
        return 0
    fi

    printf '%s' "main"
}

_ssafy_sha256_of_file() {
    local file="$1"

    if _ssafy_command_exists sha256sum; then
        sha256sum "$file" | awk '{print $1}'
        return 0
    fi

    if _ssafy_command_exists shasum; then
        shasum -a 256 "$file" | awk '{print $1}'
        return 0
    fi

    return 1
}

_ssafy_verify_archive_checksum() {
    local archive_file="$1"
    local tarball_url="$2"
    local checksum_file="$3"
    local actual=""
    local expected=""

    if ! actual=$(_ssafy_sha256_of_file "$archive_file"); then
        echo "[warn] sha256 tool missing. Skip checksum verification."
        return 0
    fi

    if [ -n "${SSAFY_TARBALL_SHA256:-}" ]; then
        if [ "$actual" != "${SSAFY_TARBALL_SHA256}" ]; then
            echo "[error] Tarball checksum mismatch."
            return 1
        fi
        return 0
    fi

    if _ssafy_command_exists curl && curl -fsSL "${tarball_url}.sha256" -o "$checksum_file" 2>/dev/null; then
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

_ssafy_write_install_meta() {
    local script_dir="$1"
    local mode="$2"
    local channel="$3"
    local ref="$4"
    local version="$5"
    local installed_at=""

    installed_at=$(date +"%Y-%m-%dT%H:%M:%S%z")
    cat > "$script_dir/$SSAFY_INSTALL_META_FILE" <<EOF
mode=$mode
channel=$channel
ref=$ref
version=$version
installed_at=$installed_at
EOF
}

_ssafy_extract_snapshot_to_dir() {
    local target_dir="$1"
    local channel="$2"
    local ref=""
    local tarball_url=""
    local temp_dir=""
    local archive_file=""
    local checksum_file=""
    local version=""

    if ! _ssafy_command_exists curl; then
        echo "[error] snapshot update requires curl."
        return 1
    fi

    if ! _ssafy_command_exists tar; then
        echo "[error] snapshot update requires tar."
        return 1
    fi

    ref=$(_ssafy_resolve_snapshot_ref "$channel")
    tarball_url=$(_ssafy_build_tarball_url "$ref")

    temp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t ssafy_tools_update)
    archive_file="$temp_dir/repo.tar.gz"
    checksum_file="$temp_dir/repo.tar.gz.sha256"

    if ! curl -fsSL "$tarball_url" -o "$archive_file"; then
        if [ "$ref" != "main" ]; then
            echo "[warn] Failed to download ref tarball. Retrying with main."
            ref="main"
            tarball_url=$(_ssafy_build_tarball_url "$ref")
            curl -fsSL "$tarball_url" -o "$archive_file" || {
                echo "[error] Snapshot download failed."
                rm -rf "$temp_dir"
                return 1
            }
        else
            echo "[error] Snapshot download failed."
            rm -rf "$temp_dir"
            return 1
        fi
    fi

    _ssafy_verify_archive_checksum "$archive_file" "$tarball_url" "$checksum_file" || {
        rm -rf "$temp_dir"
        return 1
    }

    rm -rf "$target_dir"
    mkdir -p "$target_dir"

    if ! tar -xzf "$archive_file" -C "$target_dir" --strip-components=1; then
        echo "[error] Snapshot extraction failed."
        rm -rf "$temp_dir"
        return 1
    fi

    if [ -d "$target_dir/.git" ]; then
        rm -rf "$target_dir/.git"
    fi

    version=$(_ssafy_read_version_from_dir "$target_dir")
    _ssafy_write_install_meta "$target_dir" "snapshot" "$channel" "$ref" "$version"

    rm -rf "$temp_dir"
    return 0
}

_ssafy_smoke_check_install() {
    local script_dir="$1"

    [ -f "$script_dir/algo_functions.sh" ] &&
    [ -d "$script_dir/lib" ] &&
    [ -f "$script_dir/lib/update.sh" ] &&
    [ -f "$script_dir/VERSION" ]
}

_ssafy_swap_with_backup() {
    local script_dir="$1"
    local staged_dir="$2"
    local backup_dir=""

    backup_dir="${script_dir}.backup.$(date +%Y%m%d%H%M%S)"

    if [ -d "$script_dir" ]; then
        mv "$script_dir" "$backup_dir" || {
            echo "[error] Failed to back up current install."
            return 1
        }
    fi

    mv "$staged_dir" "$script_dir" || {
        echo "[error] Failed to move staged install. Restoring backup."
        rm -rf "$script_dir"
        if [ -d "$backup_dir" ]; then
            mv "$backup_dir" "$script_dir" || true
        fi
        return 1
    }

    echo "[info] Backup path: $backup_dir"
    return 0
}

_ssafy_update_git_install() {
    local script_dir="$1"

    if [ ! -d "$script_dir/.git" ]; then
        echo "[error] Not a git install."
        return 1
    fi

    (
        cd "$script_dir" || exit 1
        git fetch --all
        git reset --hard origin/main
    )
}

_ssafy_update_snapshot_install() {
    local script_dir="$1"
    local channel="$2"
    local staged_dir=""
    local current_version=""
    local next_version=""
    local current_ref=""
    local next_ref=""

    staged_dir=$(mktemp -d 2>/dev/null || mktemp -d -t ssafy_tools_stage)

    _ssafy_extract_snapshot_to_dir "$staged_dir" "$channel" || {
        rm -rf "$staged_dir"
        return 1
    }

    if ! _ssafy_smoke_check_install "$staged_dir"; then
        echo "[error] Staged snapshot smoke check failed."
        rm -rf "$staged_dir"
        return 1
    fi

    current_version=$(_ssafy_read_version_from_dir "$script_dir")
    next_version=$(_ssafy_read_version_from_dir "$staged_dir")
    current_ref=$(_ssafy_read_meta_value "$script_dir" "ref" 2>/dev/null || true)
    next_ref=$(_ssafy_read_meta_value "$staged_dir" "ref" 2>/dev/null || true)

    if [ "$channel" = "stable" ] && [ "$current_version" = "$next_version" ] && [ "$current_ref" = "$next_ref" ]; then
        echo "Already up to date. (version: $current_version)"
        rm -rf "$staged_dir"
        return 0
    fi

    _ssafy_swap_with_backup "$script_dir" "$staged_dir" || {
        rm -rf "$staged_dir"
        return 1
    }

    echo "Snapshot update completed. (from: $current_version to: $next_version)"
    return 0
}

_ssafy_migrate_legacy_git_install() {
    local script_dir="$1"
    local channel="$2"
    local staged_dir=""

    echo "Migrating legacy git install to snapshot mode..."
    staged_dir=$(mktemp -d 2>/dev/null || mktemp -d -t ssafy_tools_migrate)

    _ssafy_extract_snapshot_to_dir "$staged_dir" "$channel" || {
        rm -rf "$staged_dir"
        return 1
    }

    if ! _ssafy_smoke_check_install "$staged_dir"; then
        echo "[error] Snapshot validation failed during migration."
        rm -rf "$staged_dir"
        return 1
    fi

    _ssafy_swap_with_backup "$script_dir" "$staged_dir" || {
        rm -rf "$staged_dir"
        return 1
    }

    echo "Legacy git install migrated to snapshot mode."
    return 0
}
ssafy_algo_update() {
    local script_dir="${ALGO_ROOT_DIR:-$HOME/.ssafy-tools}"
    local install_mode=""
    local channel=""
    local current_version=""
    local applied_version=""
    local applied_mode=""
    local applied_channel=""
    local applied_ref=""
    local answer=""

    if [ ! -d "$script_dir" ]; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "Install path not found: $script_dir"
        else
            echo "[error] Install path not found: $script_dir"
        fi
        return 1
    fi

    install_mode=$(_ssafy_resolve_install_mode "$script_dir")
    channel=$(_ssafy_resolve_update_channel "$script_dir")
    current_version=$(_ssafy_read_version_from_dir "$script_dir")

    if type ui_header >/dev/null 2>&1; then
        ui_header "algo-update" "Update execution plan"
        ui_info "install_mode=$install_mode"
        ui_info "channel=$channel"
        ui_info "current_version=$current_version"
        ui_path "$script_dir"
    else
        echo "Install path: $script_dir"
        echo "Updating... (mode: $install_mode, channel: $channel)"
    fi

    if _is_interactive && type input_confirm >/dev/null 2>&1; then
        if [ "$install_mode" = "legacy-git" ]; then
            if type ui_warn >/dev/null 2>&1; then
                ui_warn "Legacy git install will migrate to snapshot mode."
            else
                echo "[warn] Legacy git install will migrate to snapshot mode."
            fi
            input_confirm answer "Proceed with migration + update?" "n"
            case $? in
                10|20) return 1 ;;
            esac
            if [ "$answer" != "yes" ]; then
                return 1
            fi
        else
            input_confirm answer "Proceed with update now?" "y"
            case $? in
                10|20) return 1 ;;
            esac
            if [ "$answer" != "yes" ]; then
                return 1
            fi
        fi
    fi

    case "$install_mode" in
        git)
            _ssafy_update_git_install "$script_dir" || {
                if type ui_error >/dev/null 2>&1; then
                    ui_error "Git mode update failed."
                else
                    echo "[error] Git mode update failed."
                fi
                return 1
            }
            ;;
        legacy-git)
            _ssafy_migrate_legacy_git_install "$script_dir" "$channel" || {
                if type ui_error >/dev/null 2>&1; then
                    ui_error "Legacy git migration failed."
                else
                    echo "[error] Legacy git migration failed."
                fi
                return 1
            }
            ;;
        snapshot|*)
            _ssafy_update_snapshot_install "$script_dir" "$channel" || {
                if type ui_error >/dev/null 2>&1; then
                    ui_error "Snapshot update failed."
                else
                    echo "[error] Snapshot update failed."
                fi
                return 1
            }
            ;;
    esac

    applied_version=$(_ssafy_read_version_from_dir "$script_dir")
    applied_mode=$(_ssafy_read_meta_value "$script_dir" "mode" 2>/dev/null || true)
    applied_channel=$(_ssafy_read_meta_value "$script_dir" "channel" 2>/dev/null || true)
    applied_ref=$(_ssafy_read_meta_value "$script_dir" "ref" 2>/dev/null || true)

    if type ui_ok >/dev/null 2>&1; then
        ui_ok "Update completed."
        ui_info "install_path=$script_dir"
        ui_info "applied_version=$applied_version"
        ui_info "applied_mode=${applied_mode:-unknown}"
        ui_info "applied_channel=${applied_channel:-unknown}"
        ui_info "applied_ref=${applied_ref:-unknown}"
        ui_hint "Apply changes: source ~/.bashrc"
        ui_info "Verify load: type -a gitup"
        ui_info "Verify path: echo \$ALGO_ROOT_DIR"
    else
        echo ""
        echo "Update completed."
        echo "install_path=$script_dir"
        echo "applied_version=$applied_version"
        echo "applied_mode=${applied_mode:-unknown}"
        echo "applied_channel=${applied_channel:-unknown}"
        echo "applied_ref=${applied_ref:-unknown}"
        echo "Open a new terminal or run 'source ~/.bashrc' to apply changes."
        echo "Verify load: type -a gitup"
        echo "Verify path: echo \$ALGO_ROOT_DIR"
        echo ""
    fi

    if _is_interactive && type input_confirm >/dev/null 2>&1; then
        input_confirm answer "Restart shell now?" "n"
        case $? in
            10|20) return 0 ;;
        esac
        if [ "$answer" = "yes" ]; then
            exec bash
        fi
    else
        read -r -p "Restart shell now? (y/n, default=N): " restart_choice
        case "$restart_choice" in
            y|Y|yes|YES) exec bash ;;
        esac
    fi
}
_ssafy_check_update_git() {
    local script_dir="$1"
    local local_hash=""
    local remote_hash=""

    if ! _ssafy_command_exists git; then
        return 0
    fi

    (
        cd "$script_dir" || exit
        if _ssafy_command_exists timeout; then
            timeout 2s git fetch origin main >/dev/null 2>&1 || exit 0
        else
            git fetch origin main >/dev/null 2>&1 || exit 0
        fi

        local_hash=$(git rev-parse HEAD 2>/dev/null || echo "")
        remote_hash=$(git rev-parse origin/main 2>/dev/null || echo "")

        if [ -n "$local_hash" ] && [ -n "$remote_hash" ] && [ "$local_hash" != "$remote_hash" ]; then
            echo ""
            echo "[Update] New version is available. (current: ${ALGO_FUNCTIONS_VERSION:-Unknown})"
            echo "         Run 'algo-update'"
            echo ""
        fi
    )
}

_ssafy_check_update_snapshot() {
    local script_dir="$1"
    local channel="$2"
    local local_version=""
    local remote_version=""

    if ! _ssafy_command_exists curl; then
        return 0
    fi

    local_version=$(_ssafy_read_version_from_dir "$script_dir")

    if [ "$channel" = "stable" ]; then
        remote_version=$(_ssafy_fetch_latest_release_tag || true)
    else
        remote_version=$(curl -fsSL "https://raw.githubusercontent.com/$(_ssafy_repo_owner)/$(_ssafy_repo_name)/main/VERSION" 2>/dev/null || true)
        remote_version="${remote_version//$'\r'/}"
        remote_version="${remote_version//[[:space:]]/}"
    fi

    if [ -n "$remote_version" ] && [ "$remote_version" != "$local_version" ]; then
        echo ""
        echo "[Update] New version is available. (current: $local_version, latest: $remote_version)"
        echo "         Run 'algo-update'"
        echo ""
    fi
}

# Check update notification once per 24 hours
_check_update() {
    local script_dir="${ALGO_ROOT_DIR:-$HOME/.ssafy-tools}"
    local mode=""
    local channel=""

    if [ ! -d "$script_dir" ]; then
        return 0
    fi

    if [ -f "$ALGO_UPDATE_CHECK_FILE" ]; then
        local last_check=""
        local current_time=""
        local diff=""

        last_check=$(cat "$ALGO_UPDATE_CHECK_FILE" 2>/dev/null || echo 0)
        current_time=$(date +%s)
        diff=$((current_time - last_check))
        if [ "$diff" -lt 86400 ]; then
            return 0
        fi
    fi

    mode=$(_ssafy_resolve_install_mode "$script_dir")
    channel=$(_ssafy_resolve_update_channel "$script_dir")

    (
        case "$mode" in
            git)
                _ssafy_check_update_git "$script_dir"
                ;;
            legacy-git)
                echo ""
                echo "[Update] Legacy git install detected."
                echo "         'algo-update' will migrate to snapshot mode."
                echo ""
                ;;
            snapshot|*)
                _ssafy_check_update_snapshot "$script_dir" "$channel"
                ;;
        esac

        date +%s > "$ALGO_UPDATE_CHECK_FILE"
    ) &
    disown 2>/dev/null || true
}