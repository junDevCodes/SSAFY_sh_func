# =============================================================================
# lib/git.sh
# Git Workflow & SSAFY Automation
# =============================================================================

_find_ssafy_session_root() {
    local start_dir="${1:-$(pwd)}"
    local dir="$start_dir"

    while true; do
        if [ -f "$dir/.ssafy_session_root" ] || [ -f "$dir/.ssafy_playlist" ] || [ -f "$dir/.ssafy_session_meta" ]; then
            echo "$dir"
            return 0
        fi
        if [ -z "$dir" ] || [ "$dir" = "/" ] || [ "$dir" = "$HOME" ] || [ "$dir" = "." ]; then
            break
        fi
        dir="$(dirname "$dir")"
    done

    return 1
}

# _confirm_commit_message_legacy 는 _confirm_commit_message_styled로 통합되었습니다.
# 하위 호환성을 위해 아래와 같이 에일리어스 처리한다.
_confirm_commit_message_legacy() { _confirm_commit_message_styled "$@"; }

_confirm_commit_message_styled() {
    local msg="$1"
    local answer=""

    CONFIRMED_COMMIT_MSG=""

    while true; do
        echo "Current commit message: $msg"
        read -r -p "Proceed with this message for commit/push? (y/n): " answer
        case "$answer" in
            y|Y)
                CONFIRMED_COMMIT_MSG="$msg"
                return 0
                ;;
            n|N)
                read -r -p "Enter a new commit message: " msg
                if [ -z "${msg//[[:space:]]/}" ]; then
                    echo "Commit message cannot be empty."
                    return 1
                fi
                ;;
            *)
                echo "Please select y or n."
                ;;
        esac
    done
}

_handle_git_commit() {
    local target_path="$1"
    local problem="$2"
    local custom_msg="$3"
    local lang="$4"

    local original_dir
    original_dir=$(pwd)

    local git_root=""
    local current_dir="$(dirname "$target_path")"

    while [ "$current_dir" != "/" ] && [ "$current_dir" != "$HOME" ]; do
        if [ -d "$current_dir/.git" ]; then
            git_root="$current_dir"
            break
        fi
        current_dir=$(dirname "$current_dir")
    done

    if [ -z "$git_root" ]; then
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "Git repository not found."
        else
            echo "[WARN] Git repository not found."
        fi
        return 0
    fi

    cd "$git_root" || return 1

    local py_cmd=""
    if type _ssafy_python_lookup >/dev/null 2>&1; then
        py_cmd=$(_ssafy_python_lookup)
    fi
    [ -z "$py_cmd" ] && py_cmd="python3"

    local relative_path=""
    relative_path=$(realpath --relative-to="$git_root" "$target_path" 2>/dev/null || \
        "$py_cmd" -c "import os.path; print(os.path.relpath('$target_path', '$git_root'))")

    if type ui_info >/dev/null 2>&1; then
        ui_info "git_root=$git_root"
        ui_info "target=$relative_path"
    else
        echo "[INFO] git_root=$git_root"
        echo "[INFO] target=$relative_path"
    fi

    local relative_dir
    relative_dir=$(dirname "$relative_path")
    git add "$relative_dir"

    local commit_msg=""
    if [ -n "$custom_msg" ]; then
        _confirm_commit_message_styled "$custom_msg" || {
            cd "$original_dir" 2>/dev/null || true
            return 1
        }
        commit_msg="$CONFIRMED_COMMIT_MSG"
    else
        local lang_label="Python"
        [ "$lang" = "cpp" ] && lang_label="C++"
        commit_msg="${GIT_COMMIT_PREFIX}: ${problem} ${lang_label}"
    fi

    if git commit -m "$commit_msg" 2>/dev/null; then
        if type ui_ok >/dev/null 2>&1; then
            ui_ok "commit completed: $commit_msg"
        else
            echo "[OK] commit completed: $commit_msg"
        fi

        if [ "$GIT_AUTO_PUSH" = true ]; then
            local current_branch
            current_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)

            if git push origin "$GIT_DEFAULT_BRANCH" 2>/dev/null; then
                if type ui_ok >/dev/null 2>&1; then
                    ui_ok "push completed: origin/$GIT_DEFAULT_BRANCH"
                else
                    echo "[OK] push completed: origin/$GIT_DEFAULT_BRANCH"
                fi
            else
                if [ -n "$current_branch" ] && [ "$current_branch" != "$GIT_DEFAULT_BRANCH" ]; then
                    if git push origin "$current_branch" 2>/dev/null; then
                        if type ui_ok >/dev/null 2>&1; then
                            ui_ok "push completed: origin/$current_branch"
                        else
                            echo "[OK] push completed: origin/$current_branch"
                        fi
                    else
                        if type ui_warn >/dev/null 2>&1; then
                            ui_warn "Push failed: retried origin/$GIT_DEFAULT_BRANCH and origin/$current_branch"
                        else
                            echo "[WARN] push failed. tried origin/$GIT_DEFAULT_BRANCH and origin/$current_branch"
                        fi
                    fi
                else
                    if type ui_warn >/dev/null 2>&1; then
                        ui_warn "push failed: origin/$GIT_DEFAULT_BRANCH"
                    else
                        echo "[WARN] push failed: origin/$GIT_DEFAULT_BRANCH"
                    fi
                fi
            fi
        fi
    else
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "No changes to commit."
        else
            echo "[WARN] No changes to commit."
        fi
    fi

    cd "$original_dir" 2>/dev/null || true
}
_open_browser() {
    local url="$1"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || command -v powershell.exe > /dev/null 2>&1; then
        start "" "$url" 2>/dev/null || powershell.exe -Command "Start-Process '$url'" 2>/dev/null
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        open "$url"
    else
        xdg-open "$url" 2>/dev/null || echo "$url"
    fi
}

_ssafy_base64_decode() {
    local value="$1"

    # Remove CRLF/spaces from base64 input before decoding.
    value="${value//[[:space:]]/}"

    # Windows(Git Bash)/Linux: base64 -d, macOS: base64 -D
    local decoded=""
    decoded=$(echo "$value" | base64 -d 2>/dev/null || echo "")
    if [ -z "$decoded" ]; then
        decoded=$(echo "$value" | base64 -D 2>/dev/null || echo "")
    fi
    echo "$decoded"
}

_show_submission_links() {
    local ssafy_root="$1"
    shift
    local folders=("$@")

    local has_link=false
    local urls=()
    local index=1

    local meta_file="$ssafy_root/.ssafy_session_meta"
    [ -f "$meta_file" ] || return 0

    local course_id=""
    local course_id_enc=""
    course_id_enc=$(grep "^course_id_enc=" "$meta_file" 2>/dev/null | cut -d= -f2)
    if [ -n "$course_id_enc" ]; then
        course_id=$(_ssafy_base64_decode "$course_id_enc")
    else
        local raw_course_id=""
        raw_course_id=$(grep "^course_id=" "$meta_file" 2>/dev/null | cut -d= -f2)
        local decoded_course_id=""
        decoded_course_id=$(_ssafy_base64_decode "$raw_course_id")
        if [[ "$decoded_course_id" =~ ^CS[0-9]+$ ]]; then
            course_id="$decoded_course_id"
        else
            course_id="$raw_course_id"
        fi
    fi

    [ -n "$course_id" ] || return 0

    local lines=()
    local line=""
    while IFS= read -r line || [ -n "$line" ]; do
        lines+=("$line")
    done < "$meta_file"

    local idx=0
    local len=${#lines[@]}
    while [ $idx -lt $len ]; do
        line="${lines[$idx]}"
        if [[ "$line" == *"="* ]]; then
            idx=$((idx + 1))
            continue
        fi

        local folder=""
        for folder in "${folders[@]}"; do
            if [ "$line" = "$folder" ] && [ $((idx + 2)) -lt $len ]; then
                local pr_id
                local pa_id
                pr_id=$(_ssafy_base64_decode "${lines[$((idx + 1))]}")
                pa_id=$(_ssafy_base64_decode "${lines[$((idx + 2))]}")
                if [ -n "$pr_id" ] && [ -n "$pa_id" ]; then
                    local link="https://project.ssafy.com/practiceroom/course/${course_id}/practice/${pr_id}/answer/${pa_id}"
                    echo "$index. $folder: $link"
                    urls+=("$link")
                    has_link=true
                    index=$((index + 1))
                fi
                break
            fi
        done

        idx=$((idx + 1))
    done

    [ "$has_link" = true ] || return 0

    if _is_interactive; then
        local choice=""
        echo ""
        echo "Actions: a=open all, [number]=open one, Enter=skip"
        read -r choice

        if [ "$choice" = "a" ]; then
            local url=""
            for url in "${urls[@]}"; do
                [ -n "$url" ] || continue
                _open_browser "$url"
                sleep 0.5
            done
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#urls[@]} ]; then
            _open_browser "${urls[$((choice - 1))]}"
        fi
    fi
}
_open_repo_file() {
    local repo_dir="$1"
    local abs_repo_dir=""

    abs_repo_dir="$(cd "$repo_dir" 2>/dev/null && pwd)" || {
        if type ui_error >/dev/null 2>&1; then
            ui_error "Directory not found: $repo_dir"
        else
            echo "[ERROR] Directory not found: $repo_dir"
        fi
        return 1
    }

    if [ ! -d "$abs_repo_dir" ]; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "Directory not found: $abs_repo_dir"
        else
            echo "[ERROR] Directory not found: $abs_repo_dir"
        fi
        return 1
    fi

    cd "$abs_repo_dir" || return 1

    local ide_cmd=""
    ide_cmd=$(get_active_ide)

    if [ -n "$ide_cmd" ]; then
        if type ui_step >/dev/null 2>&1; then
            ui_step "Open repository in IDE: $ide_cmd"
        else
            echo "[STEP] Open repository in IDE: $ide_cmd"
        fi

        if [[ "$ide_cmd" != "code" && "$ide_cmd" != "cursor" ]]; then
            # 비-VSCode IDE: 디렉토리를 백그라운드로 오픈
            "$ide_cmd" "$abs_repo_dir" &
        fi
        # code/cursor: workspace 교체 없이 파일만 열기 → 아래 파일 선택 로직에서 code -r -g 로 처리
    else
        if type ui_warn > /dev/null 2>&1; then
            ui_warn "No IDE command detected."
        else
            echo "[WARN] No IDE command detected."
        fi
    fi

    local files=()
    local file=""
    while IFS= read -r file; do
        [ -n "$file" ] && files+=("${file#./}")
    done < <(find . -maxdepth 3 -not -path '*/.*' -type f 2>/dev/null | head -n 6)

    local count=${#files[@]}
    if [ $count -eq 0 ]; then
        if type ui_info >/dev/null 2>&1; then
            ui_info "No files found in repository yet."
        else
            echo "[INFO] No files found in repository yet."
        fi
        return 0
    fi

    if type ui_section >/dev/null 2>&1; then
        ui_section "Repository files (top 5)"
    fi

    local idx=0
    for file in "${files[@]}"; do
        if [ $idx -lt 5 ]; then
            echo "  - $file"
        fi
        idx=$((idx + 1))
    done
    if [ $count -gt 5 ]; then
        echo "  - ..."
    fi

    if _is_interactive && [ $count -gt 0 ] && [ -n "$ide_cmd" ] && [[ "$ide_cmd" == "code" || "$ide_cmd" == "cursor" ]]; then
        local choice=""
        input_text choice "Open file number (Enter to skip)" "" true
        case $? in
            10|20) return 0 ;;
        esac
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
            "$ide_cmd" -r -g "$abs_repo_dir/${files[$((choice - 1))]}"
        fi
    fi
}
_ssafy_next_repo() {
    local repo_name="$1"
    
    if [ -f ".ssafy_playlist" ]; then
        local -a playlist=()
        while IFS= read -r line; do
            line="${line//$'\r'/}"
            if [ -n "$line" ]; then
                playlist+=("$line")
            fi
        done < ".ssafy_playlist"
        
        local i
        for i in "${!playlist[@]}"; do
            if [ "${playlist[$i]}" == "$repo_name" ]; then
                local next_idx=$((i + 1))
                if [ -n "${playlist[$next_idx]}" ]; then
                    echo "${playlist[$next_idx]}"
                    return 0
                fi
            fi
        done
    fi

    local topic=""
    local kind=""
    local session=""
    local number=""

    if ! [[ "$repo_name" =~ ^([A-Za-z0-9]+)_(ws|hw|ex)_([0-9]+)_([0-9]+)$ ]]; then
        return 1
    fi

    topic="${BASH_REMATCH[1]}"
    kind="${BASH_REMATCH[2]}"
    session="${BASH_REMATCH[3]}"
    number="${BASH_REMATCH[4]}"

    if [ "$kind" = "ws" ]; then
        if [ "$number" -lt 5 ]; then
            number=$((number + 1))
            echo "${topic}_ws_${session}_${number}"
            return 0
        elif [ "$number" -eq 5 ]; then
            echo "${topic}_hw_${session}_2"
            return 0
        fi
    elif [ "$kind" = "hw" ]; then
        if [ "$number" -eq 2 ]; then
            echo "${topic}_hw_${session}_4"
            return 0
        fi
    fi

    return 1
}

# =============================================================================
# Keep only the latest state per key in .ssafy_progress.
_ssafy_progress_compact() {
    local progress_file="$1"
    [ -f "$progress_file" ] || return 0

    # If the same key appears multiple times, keep the last value.
    local tmp_file="${progress_file}.tmp.$$"
    awk -F= '
        NF >= 2 {
            k = $1
            v = $2
            if (!(k in order)) { order[++n] = k }
            val[k] = v
        }
        END {
            for (i = 1; i <= n; i++) {
                k = order[i]
                if (k != "") { print k "=" val[k] }
            }
        }
    ' "$progress_file" > "$tmp_file" 2>/dev/null || return 0

    mv "$tmp_file" "$progress_file" 2>/dev/null || rm -f "$tmp_file" 2>/dev/null || true
}

_ssafy_progress_set() {
    local ssafy_root="$1"
    local repo_name="$2"
    local state="$3" # init|done
    local progress_file="$ssafy_root/.ssafy_progress"

    [ -f "$progress_file" ] || : > "$progress_file"

    # Keep done state from being downgraded to init
    if [ "$state" = "init" ] && grep -q "^${repo_name}=done$" "$progress_file" 2>/dev/null; then
        return 0
    fi

    if grep -q "^${repo_name}=" "$progress_file" 2>/dev/null; then
        if type _sed_inplace >/dev/null 2>&1; then
            _sed_inplace "s|^${repo_name}=.*|${repo_name}=${state}|" "$progress_file"
        else
            if sed --version >/dev/null 2>&1; then
                sed -i "s|^${repo_name}=.*|${repo_name}=${state}|" "$progress_file"
            else
                sed -i '' "s|^${repo_name}=.*|${repo_name}=${state}|" "$progress_file"
            fi
        fi
    else
        echo "${repo_name}=${state}" >> "$progress_file"
    fi

    _ssafy_progress_compact "$progress_file"
}
_sync_playlist_status() {
    local ssafy_root="$1"
    local user_name=$(git config user.name)
    local prefix="${GIT_COMMIT_PREFIX:-solve}"
    local progress_file="$ssafy_root/.ssafy_progress"
    
    if [ -z "$user_name" ]; then return; fi
    if [ ! -f "$progress_file" ]; then touch "$progress_file"; fi
    
    local original_dir=$(pwd)
    cd "$ssafy_root" || return
    
    for folder in *_ws_* *_hw_* *_ex_*; do
        if [ -d "$folder" ] && [ -d "$folder/.git" ]; then
            if grep -q "^${folder}=done" "$progress_file" 2>/dev/null; then
                continue
            fi
            
            cd "$folder"
            if git log --author="$user_name" --oneline -n 20 2>/dev/null | grep -qE "[a-f0-9]+ ${prefix}:"; then
                 _ssafy_progress_set "$ssafy_root" "$folder" "done"
            fi
            cd ..
        fi
    done
    
    cd "$original_dir"
}

_check_unsolved_folders() {
    local ssafy_root="$1"
    shift
    local all_folders=("$@")
    local progress_file="$ssafy_root/.ssafy_progress"
    local unsolved=()
    local folder=""

    for folder in "${all_folders[@]}"; do
        if ! grep -q "^${folder}=done" "$progress_file" 2>/dev/null; then
            unsolved+=("$folder")
        fi
    done

    if [ ${#unsolved[@]} -gt 0 ]; then
        echo ""
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "Unsolved folders remain: ${#unsolved[@]}"
        else
            echo "[WARN] Unsolved folders remain: ${#unsolved[@]}"
        fi

        local i=1
        for folder in "${unsolved[@]}"; do
            echo "  $i. $folder"
            i=$((i + 1))
        done

        if _is_interactive; then
            local choice=""
            input_text choice "Select folder number to open (Enter to skip)" "" true
            case $? in
                10|20) return 1 ;;
            esac
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#unsolved[@]} ]; then
                _open_repo_file "$ssafy_root/${unsolved[$((choice - 1))]}"
            fi
        fi
        return 1
    fi

    if type ui_ok >/dev/null 2>&1; then
        ui_ok "All folders are marked done."
    else
        echo "[OK] All folders are marked done."
    fi
    _show_submission_links "$ssafy_root" "${all_folders[@]}"
    return 0
}
_gitdown_all() {
    local ssafy_root=""
    ssafy_root=$(_find_ssafy_session_root "$(pwd)" 2>/dev/null || true)

    if [ -z "$ssafy_root" ] && [ -n "${SSAFY_SESSION_ROOT:-}" ] && [ -d "$SSAFY_SESSION_ROOT" ]; then
        ssafy_root="$SSAFY_SESSION_ROOT"
    fi

    if [ -z "$ssafy_root" ]; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "SSAFY session root not found."
        else
            echo "[ERROR] SSAFY session root not found."
        fi
        return 1
    fi

    cd "$ssafy_root" || return 1

    local folders=()
    local folder=""
    if [ -f ".ssafy_playlist" ]; then
        while IFS= read -r folder; do
            [ -d "$folder" ] && folders+=("$folder")
        done < ".ssafy_playlist"
    else
        for folder in */; do
            folder="${folder%/}"
            if [[ "$folder" =~ ^[A-Za-z0-9]+_(ws|hw|ex)_[0-9]+(_[0-9]+)?$ ]]; then
                folders+=("$folder")
            fi
        done
    fi

    if [ ${#folders[@]} -eq 0 ]; then
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "No target folders found."
        else
            echo "[WARN] No target folders found."
        fi
        return 0
    fi

    local success_count=0
    local fail_count=0
    local skip_count=0
    local pushed_folders=()

    for folder in "${folders[@]}"; do
        cd "$ssafy_root/$folder" || {
            fail_count=$((fail_count + 1))
            continue
        }

        if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
            skip_count=$((skip_count + 1))
            cd "$ssafy_root" || return 1
            continue
        fi

        git add .
        if git commit -m "${GIT_COMMIT_PREFIX:-solve}: $folder" 2>/dev/null; then
            if git push 2>/dev/null; then
                success_count=$((success_count + 1))
                pushed_folders+=("$folder")
                _ssafy_progress_set "$ssafy_root" "$folder" "done"
            else
                fail_count=$((fail_count + 1))
            fi
        else
            skip_count=$((skip_count + 1))
        fi

        cd "$ssafy_root" || return 1
    done

    if type ui_panel_begin >/dev/null 2>&1; then
        ui_panel_begin "gitdown" "Commit follow-up"
        ui_info "success=$success_count"
        ui_info "failed=$fail_count"
        ui_info "skipped=$skip_count"
    else
        echo "Result: success=$success_count failed=$fail_count skipped=$skip_count"
    fi

    _check_unsolved_folders "$ssafy_root" "${folders[@]}"
    local playlist_complete=$?

    if [ "$playlist_complete" -ne 0 ] && [ ${#pushed_folders[@]} -gt 0 ]; then
        _show_submission_links "$ssafy_root" "${pushed_folders[@]}"
    fi
}
_ssafy_git_is_valid_url() {
    local value="$1"
    [[ "$value" =~ ^https?:// ]]
}

_ssafy_git_is_valid_topic() {
    local value="$1"
    case "$value" in
        *_ws_*|*_hw_*|*_ex_*) ;;
        *) return 1 ;;
    esac
    printf '%s' "$value" | grep -Eq '^[A-Za-z0-9_]+$'
}

_gitup_debug_log() {
    if [ -z "${SSAFY_DEBUG_FLOW:-}" ]; then
        return 0
    fi
    echo "[DEBUG][gitup] $*"
}

_ssafy_gitup_prompt_flow() {
    local mode="1"
    local input_value=""
    local answer=""
    local rc=0
    local repo_estimate="1"
    local step=1
    local smart_url=""

    if ! type input_choice >/dev/null 2>&1; then
        return 1
    fi

    while true; do
        case "$step" in
            1)
                input_choice mode "Step 1/4: Select input mode" "$mode" "1:SmartLink" "2:URL" "3:Topic"
                rc=$?
                _gitup_debug_log "step=1 rc=$rc mode=$mode"
                case "$rc" in
                    20) return 20 ;;
                    10) return 20 ;;
                    0) step=2 ;;
                    *) return 1 ;;
                esac
                ;;
            2)
                case "$mode" in
                    1)
                        input_masked input_value "Step 2/4: Paste SmartLink (URL|Token): "
                        rc=$?
                        _gitup_debug_log "step=2 mode=SmartLink rc=$rc input_len=${#input_value}"
                        ;;
                    2)
                        input_text input_value "Step 2/4: Enter repository URL" "$input_value"
                        rc=$?
                        _gitup_debug_log "step=2 mode=URL rc=$rc input=$input_value"
                        ;;
                    3)
                        input_text input_value "Step 2/4: Enter topic (e.g. algo_ws_3)" "$input_value"
                        rc=$?
                        _gitup_debug_log "step=2 mode=Topic rc=$rc input=$input_value"
                        ;;
                    *)
                        return 1
                        ;;
                esac

                case "$rc" in
                    10) step=1; continue ;;
                    20) return 20 ;;
                    0) ;;
                    *) return 1 ;;
                esac

                case "$mode" in
                    1)
                        if [[ "$input_value" != *"|"* ]]; then
                            if type ui_warn >/dev/null 2>&1; then
                                ui_warn "SmartLink must contain 'URL|Token'."
                                ui_info "Example: https://lab.ssafy.com/...|Bearer ..."
                            else
                                echo "[WARN] SmartLink must contain 'URL|Token'."
                                echo "[INFO] Example: https://lab.ssafy.com/...|Bearer ..."
                            fi
                            continue
                        fi
                        smart_url="${input_value%%|*}"
                        if ! _ssafy_git_is_valid_url "$smart_url"; then
                            if type ui_warn >/dev/null 2>&1; then
                                ui_warn "SmartLink URL must start with http:// or https://"
                            else
                                echo "[WARN] SmartLink URL must start with http:// or https://"
                            fi
                            continue
                        fi
                        repo_estimate="batch or single (depends on URL)"
                        ;;
                    2)
                        if ! _ssafy_git_is_valid_url "$input_value"; then
                            if type ui_warn >/dev/null 2>&1; then
                                ui_warn "URL must start with http:// or https://"
                            else
                                echo "[WARN] URL must start with http:// or https://"
                            fi
                            continue
                        fi
                        repo_estimate="1"
                        ;;
                    3)
                        if ! _ssafy_git_is_valid_topic "$input_value"; then
                            if type ui_warn >/dev/null 2>&1; then
                                ui_warn "Topic format must match *_ws_* or *_hw_* pattern."
                            else
                                echo "[WARN] Topic format must match *_ws_* or *_hw_* pattern."
                            fi
                            continue
                        fi
                        repo_estimate="7 (5 ws + 2 hw)"
                        ;;
                    *)
                        return 1
                        ;;
                esac

                step=3
                _gitup_debug_log "step=2 validated mode=$mode repo_estimate=$repo_estimate"
                ;;
            3)
                if type ui_panel_begin >/dev/null 2>&1; then
                    ui_panel_begin "gitup" "Step 3/4: Preview before run"
                    case "$mode" in
                        1) ui_info "Input mode=SmartLink" ;;
                        2) ui_info "Input mode=URL" ;;
                        3) ui_info "Input mode=Topic" ;;
                    esac
                    ui_info "Estimated repos=$repo_estimate"
                else
                    echo "[INFO] mode=$mode, estimated_repos=$repo_estimate"
                fi
                step=4
                _gitup_debug_log "step=3 preview_done mode=$mode repo_estimate=$repo_estimate"
                ;;
            4)
                input_confirm answer "Step 4/4: Run clone flow now?" "y"
                rc=$?
                _gitup_debug_log "step=4 rc=$rc answer=${answer:-}"
                case "$rc" in
                    0)
                        if [ "$answer" != "yes" ]; then
                            _gitup_debug_log "step=4 resolved=cancel_by_no"
                            return 20
                        fi
                        SSAFY_GITUP_FLOW_MODE="$mode"
                        SSAFY_GITUP_FLOW_INPUT="$input_value"
                        _gitup_debug_log "step=4 resolved=ok mode=$mode input=$input_value"
                        return 0
                        ;;
                    10)
                        _gitup_debug_log "step=4 resolved=back_to_step2"
                        step=2
                        continue
                        ;;
                    20)
                        _gitup_debug_log "step=4 resolved=cancel_by_q"
                        return 20
                        ;;
                    *) return 1 ;;
                esac
                ;;
            *)
                return 1
                ;;
        esac
    done
}
ssafy_gitdown() {
    init_algo_config

    # 필수 설정 가드: SSAFY_USER_ID, 커밋 접두사, 브랜치 미설정 시 차단
    _ssafy_require_config ssafy_user_id git_prefix git_branch || return 1

    local run_all=false
    local ssafy_mode=false
    local commit_msg=""
    local custom_msg=false
    local push_ok=false
    local selected_push_branch=""
    local open_submission_links=true
    local move_to_next_problem=true
    local answer=""
    local current_repo

    # SSAFY 세션 루트에서 단독 실행 시 기본적으로 전체 배치 모드
    local _ssafy_root_check
    _ssafy_root_check=$(_find_ssafy_session_root "$(pwd)" 2>/dev/null || true)
    if [ -n "$_ssafy_root_check" ] && [ "$(pwd)" = "$_ssafy_root_check" ]; then
        run_all=true
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --all|-a)
                run_all=true
                ;;
            --no-all)
                # 세션 루트에서도 단일 모드를 강제하실 때 사용
                run_all=false
                ;;
            --ssafy|-s)
                ssafy_mode=true
                ;;
            --msg|-m)
                shift
                if [ -z "${1:-}" ] || [[ "$1" == --* ]]; then
                    if type ui_error > /dev/null 2>&1; then
                        ui_error "--msg requires a commit message."
                    else
                        echo "[ERROR] --msg requires a commit message."
                    fi
                    return 1
                fi
                commit_msg="$1"
                custom_msg=true
                ;;
            --msg=*)
                commit_msg="${1#--msg=}"
                if [ -z "$commit_msg" ]; then
                    if type ui_error > /dev/null 2>&1; then
                        ui_error "--msg requires a commit message."
                    else
                        echo "[ERROR] --msg requires a commit message."
                    fi
                    return 1
                fi
                custom_msg=true
                ;;
            *)
                if [ -z "$commit_msg" ] && [[ "$1" != --* ]]; then
                    commit_msg="$1"
                    custom_msg=true
                else
                    if type ui_error > /dev/null 2>&1; then
                        ui_error "Commit message with spaces must be quoted."
                    else
                        echo "[ERROR] Commit message with spaces must be quoted."
                    fi
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [ "$run_all" = true ]; then
        if _is_interactive && type input_confirm > /dev/null 2>&1; then
            input_confirm answer "Run gitdown in batch mode (all folders)?" "y"
            case $? in
                20|10) return 1 ;;
            esac
            if [ "$answer" != "yes" ]; then
                return 1
            fi
        fi
        _gitdown_all
        return $?
    fi

    current_repo=$(basename "$(pwd)" 2>/dev/null)
    if [[ "$current_repo" =~ ^[A-Za-z0-9]+_(ws|hw|ex)(_[0-9]+(_[0-9]+)?)?$ ]]; then
        ssafy_mode=true
    fi

    if type ui_panel_begin >/dev/null 2>&1; then
        ui_panel_begin "gitdown" "Commit/Push execution"
        if [ "$ssafy_mode" = true ]; then
            ui_info "mode=ssafy"
        else
            ui_info "mode=normal"
        fi
        ui_section "Current changes"
    else
        echo "[INFO] gitdown"
    fi
    git status --short
    echo ""

    if _is_interactive && type input_choice >/dev/null 2>&1; then
        local commit_mode="auto"

        if [ "$custom_msg" = true ]; then
            commit_mode="custom"
        else
            input_choice commit_mode "Step 1/5: Commit message mode" "auto" \
                "auto:Auto generated message" \
                "custom:Manual message"
            case $? in
                10|20) return 1 ;;
            esac
        fi

        if [ "$commit_mode" = "custom" ]; then
            if [ -z "$commit_msg" ]; then
                input_text commit_msg "Step 2/5: Enter commit message" ""
                case $? in
                    10|20) return 1 ;;
                esac
            fi
            if [ -z "${commit_msg//[[:space:]]/}" ]; then
                if type ui_error >/dev/null 2>&1; then
                    ui_error "Commit message cannot be empty."
                else
                    echo "[ERROR] Commit message cannot be empty."
                fi
                return 1
            fi
            custom_msg=true
        fi

        if [ "$GIT_AUTO_PUSH" = true ]; then
            local branches=()
            local branch=""
            while IFS= read -r branch; do
                [ -n "$branch" ] && branches+=("$branch")
            done < <(git branch --list 2>/dev/null | sed 's/^[* ] //')

            if [ "${#branches[@]}" -gt 0 ]; then
                if type ui_section >/dev/null 2>&1; then
                    ui_section "Select push branch"
                else
                    echo "[Step 3/5] Push branch"
                fi
                echo "  0) Auto select"
                local i=1
                for branch in "${branches[@]}"; do
                    echo "  $i) $branch"
                    i=$((i + 1))
                done
                local branch_choice=""
                input_text branch_choice "Select branch number" "0"
                case $? in
                    10|20) return 1 ;;
                esac
                if [[ "$branch_choice" =~ ^[0-9]+$ ]] && [ "$branch_choice" -ge 1 ] && [ "$branch_choice" -le "${#branches[@]}" ]; then
                    selected_push_branch="${branches[$((branch_choice - 1))]}"
                fi
            fi
        fi

        if [ "$ssafy_mode" = true ]; then
            input_confirm answer "Step 4/5: Open submission links after push?" "y"
            case $? in
                10|20) return 1 ;;
            esac
            if [ "$answer" = "no" ]; then
                open_submission_links=false
            fi

            input_confirm answer "Step 5/5: Move to next problem after push?" "y"
            case $? in
                10|20) return 1 ;;
            esac
            if [ "$answer" = "no" ]; then
                move_to_next_problem=false
            fi
        fi

        if type ui_panel_begin >/dev/null 2>&1; then
            ui_panel_begin "gitdown" "Final confirmation"
            if [ "$custom_msg" = true ]; then
                ui_info "commit_msg=$commit_msg"
            else
                ui_info "commit_msg=auto"
            fi
            if [ -n "$selected_push_branch" ]; then
                ui_info "push_branch=$selected_push_branch"
            else
                ui_info "push_branch=auto"
            fi
        fi
        input_confirm answer "Proceed with git add/commit/push?" "y"
        case $? in
            10|20) return 1 ;;
        esac
        if [ "$answer" != "yes" ]; then
            return 1
        fi
    fi

    if [ "$custom_msg" = true ]; then
        if [ -z "${commit_msg//[[:space:]]/}" ]; then
            if type ui_error >/dev/null 2>&1; then
                ui_error "Commit message cannot be empty."
            else
                echo "[ERROR] Commit message cannot be empty."
            fi
            return 1
        fi
        if _is_interactive; then
            _confirm_commit_message "$commit_msg" || return 1
            commit_msg="$CONFIRMED_COMMIT_MSG"
        fi
    else
        if [ -z "$current_repo" ] || [ "$current_repo" = "/" ] || [ "$current_repo" = "\\" ]; then
            current_repo="update"
        fi
        commit_msg="${GIT_COMMIT_PREFIX}: $current_repo"
    fi

    git add .
    if type ui_step >/dev/null 2>&1; then
        ui_step "Commit message: $commit_msg"
    else
        echo "[STEP] commit message: $commit_msg"
    fi

    if ! git commit -m "$commit_msg"; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "Commit failed."
        else
            echo "[ERROR] Commit failed."
        fi
        return 1
    fi

    if [ "$GIT_AUTO_PUSH" = true ]; then
        local push_branch="$selected_push_branch"
        local remote_head=""
        local branches=""
        local has_master=false
        local has_main=false

        if [ -z "$push_branch" ]; then
            branches=$(git branch --list 2>/dev/null | sed 's/^[* ] //' | tr '\n' ' ')
            for branch in $branches; do
                [ "$branch" = "master" ] && has_master=true
                [ "$branch" = "main" ] && has_main=true
            done

            remote_head=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
            if [ -z "$remote_head" ]; then
                remote_head=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
            fi

            if [ -n "$remote_head" ]; then
                if [ "$remote_head" = "master" ] && [ "$has_master" = true ] && [ "$has_main" = false ]; then
                    push_branch="$remote_head"
                elif [ "$remote_head" = "main" ] && [ "$has_main" = true ] && [ "$has_master" = false ]; then
                    push_branch="$remote_head"
                fi
            fi
        fi

        if [ -z "$push_branch" ]; then
            local branch_list
            local branch_array=()
            local index=1
            local branch_choice=""
            branch_list=$(git branch --list 2>/dev/null | sed 's/^[* ] //')

            while IFS= read -r branch; do
                if [ -n "$branch" ]; then
                    echo "  $index) $branch"
                    branch_array[$index]="$branch"
                    index=$((index + 1))
                fi
            done <<< "$branch_list"

            if [ $index -eq 1 ]; then
                if type ui_warn >/dev/null 2>&1; then
                    ui_warn "No branch available for push. Skip push."
                else
                    echo "[WARN] No branch available for push. Skip push."
                fi
                push_ok=false
            else
                if _is_interactive && type input_text >/dev/null 2>&1; then
                    input_text branch_choice "Push branch number (1-$((index - 1)))" "1"
                    case $? in
                        10|20) return 1 ;;
                    esac
                else
                    branch_choice="1"
                fi

                if [ -n "$branch_choice" ] && [ "$branch_choice" -ge 1 ] && [ "$branch_choice" -lt "$index" ] 2>/dev/null; then
                    push_branch="${branch_array[$branch_choice]}"
                else
                    if type ui_warn >/dev/null 2>&1; then
                        ui_warn "Invalid branch selection. Skip push."
                    else
                        echo "[WARN] Invalid branch selection. Skip push."
                    fi
                    push_ok=false
                fi
            fi
        fi

        if [ -n "$push_branch" ]; then
            if type ui_step >/dev/null 2>&1; then
                ui_step "Push target: origin/$push_branch"
            else
                echo "[STEP] Push to origin/$push_branch"
            fi
            if git push origin "$push_branch" 2>/dev/null; then
                push_ok=true
                if type ui_ok >/dev/null 2>&1; then
                    ui_ok "Push completed"
                else
                    echo "[OK] Push completed."
                fi
            else
                push_ok=false
                if type ui_error >/dev/null 2>&1; then
                    ui_error "Push failed: origin/$push_branch"
                else
                    echo "[ERROR] Push failed: origin/$push_branch"
                fi
            fi
        fi
    fi

    cd .. || {
        if type ui_error >/dev/null 2>&1; then
            ui_error "Failed to move to parent directory."
        else
            echo "[ERROR] Failed to move to parent directory."
        fi
        return 1
    }

    if [ "$ssafy_mode" = true ]; then
        local ssafy_root=""
        ssafy_root=$(_find_ssafy_session_root "$(pwd)" 2>/dev/null || true)
        if [ -z "$ssafy_root" ] && [ -n "${SSAFY_SESSION_ROOT:-}" ] && [ -d "$SSAFY_SESSION_ROOT" ]; then
            ssafy_root="$SSAFY_SESSION_ROOT"
        fi
        if [ -n "$ssafy_root" ]; then
            cd "$ssafy_root" || return 1
        fi
    fi

    if [ "$ssafy_mode" = true ]; then
        if [ "$push_ok" = true ]; then
            if [ -n "$ssafy_root" ] && [ -f "$ssafy_root/.ssafy_progress" ]; then
                _ssafy_progress_set "$ssafy_root" "$current_repo" "done"
            fi

            if [ "$open_submission_links" = true ]; then
                _show_submission_links "$ssafy_root" "$current_repo"
            fi

            if [ "$move_to_next_problem" = true ]; then
                local next_repo
                next_repo=$(_ssafy_next_repo "$current_repo")
                if [ -n "$next_repo" ] && [ ! -d "$next_repo" ]; then
                    if type ui_warn >/dev/null 2>&1; then
                        ui_warn "Next repo is not cloned yet: $next_repo"
                    else
                        echo "[WARN] Next repo is not cloned: $next_repo"
                    fi
                fi
                if [ -n "$next_repo" ] && [ -d "$next_repo" ]; then
                    _open_repo_file "$next_repo" || true
                else
                    _sync_playlist_status "$ssafy_root"

                    local all_folders=()
                    local playlist_file="$ssafy_root/.ssafy_playlist"
                    local meta_file="$ssafy_root/.ssafy_session_meta"

                    if [ -f "$playlist_file" ]; then
                        while IFS= read -r line || [ -n "$line" ]; do
                            all_folders+=("$line")
                        done < "$playlist_file"
                    elif [ -f "$meta_file" ]; then
                        while IFS= read -r line || [ -n "$line" ]; do
                            if [[ "$line" =~ ^([^=]+)=([^=]+)$ ]]; then
                                local key="${BASH_REMATCH[1]}"
                                if [[ "$key" != "course_id" ]] && [[ "$key" != "course_id_enc" ]] && [[ "$key" != "practice_id" ]] && [[ "$key" != *"_pa" ]] && [[ "$key" != *"_enc" ]]; then
                                    all_folders+=("$key")
                                fi
                            fi
                        done < "$meta_file"
                    fi

                    if [ ${#all_folders[@]} -eq 0 ]; then
                        for d in *_ws_* *_hw_* *_ex_*; do
                            [ -d "$d" ] && all_folders+=("$d")
                        done
                    fi

                    if [ ${#all_folders[@]} -gt 0 ]; then
                        _check_unsolved_folders "$ssafy_root" "${all_folders[@]}"
                    fi
                fi
            fi
        else
            if type ui_warn >/dev/null 2>&1; then
                ui_warn "Push failed/skipped. Follow-up flow will be skipped."
            else
                echo "[WARN] Skip follow-up flow because push failed or skipped."
            fi
        fi
    fi
}
_gitup_ssafy() {
    local input="$1"

    _ensure_ssafy_config
    if [ -z "${SSAFY_BASE_URL:-}" ] || [ -z "${SSAFY_USER_ID:-}" ]; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "SSAFY settings are missing. Configure SSAFY_BASE_URL/SSAFY_USER_ID via algo-config edit."
        else
            echo "[ERROR] SSAFY settings are missing. Configure SSAFY_BASE_URL/SSAFY_USER_ID via algo-config edit."
        fi
        return 1
    fi

    local base_url="${SSAFY_BASE_URL%/}"
    local user_id="${SSAFY_USER_ID%/}"
    local repo_name="$input"
    local topic=""
    local session=""

    if [[ "$input" =~ ^https?:// ]]; then
        repo_name=$(basename "$input")
        repo_name="${repo_name%.git}"
    fi

    if [[ "$repo_name" =~ ^([A-Za-z0-9]+)_(ws|hw|ex)_([0-9]+)_[0-9]+$ ]]; then
        topic="${BASH_REMATCH[1]}"
        session="${BASH_REMATCH[3]}"
    elif [[ "$repo_name" =~ ^([A-Za-z0-9]+)_(ws|hw|ex)_([0-9]+)$ ]]; then
        topic="${BASH_REMATCH[1]}"
        session="${BASH_REMATCH[3]}"
    elif [[ "$repo_name" =~ ^([A-Za-z0-9]+)_(ws|hw|ex)$ ]]; then
        topic="${BASH_REMATCH[1]}"
        input_text session "Enter session number (e.g. 3)" "" false
        case $? in
            10|20) return 1 ;;
        esac
    elif [[ "$repo_name" =~ ^([A-Za-z0-9]+)$ ]]; then
        topic="$repo_name"
        input_text session "Enter session number (e.g. 3)" "" false
        case $? in
            10|20) return 1 ;;
        esac
    else
        if [[ "$repo_name" =~ ^(ws|hw|ex)_[0-9]+(_[0-9]+)?$ ]]; then
            if type ui_error >/dev/null 2>&1; then
                ui_error "Invalid topic format: $repo_name"
                ui_info "Example: ds_ws_2 or ds_ws_2_1"
            else
                echo "[ERROR] Invalid SSAFY topic: $repo_name"
            fi
        fi
        return 1
    fi

    if [ -z "$session" ] || ! [[ "$session" =~ ^[0-9]+$ ]]; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "Session number must be numeric."
        else
            echo "[ERROR] Session number must be numeric."
        fi
        return 1
    fi

    local repos=()
    local i=""
    for i in 1 2 3 4 5; do
        repos+=("${topic}_ws_${session}_${i}")
    done
    for i in 2 4; do
        repos+=("${topic}_hw_${session}_${i}")
    done

    local -a cloned=()
    local -a skipped=()
    local -a failed=()
    local repo=""

    for repo in "${repos[@]}"; do
        local url="${base_url}/${user_id}/${repo}"
        if [ -d "$repo" ]; then
            skipped+=("$repo")
            continue
        fi
        if git clone "$url" >/dev/null 2>&1; then
            cloned+=("$repo")
        else
            failed+=("$repo")
        fi
    done

    if type ui_panel_begin >/dev/null 2>&1; then
        ui_panel_begin "gitup" "SSAFY clone result"
        ui_info "success=${#cloned[@]}"
        ui_info "skipped=${#skipped[@]}"
        ui_info "failed=${#failed[@]}"
        if [ "${#failed[@]}" -gt 0 ]; then
            ui_warn "failed list: ${failed[*]}"
        fi
    else
        echo "Clone summary: ok=${#cloned[@]}, skipped=${#skipped[@]}, failed=${#failed[@]}"
        if [ "${#failed[@]}" -gt 0 ]; then
            echo "Failed: ${failed[*]}"
        fi
    fi

    local session_root="$(pwd)"
    export SSAFY_SESSION_ROOT="$session_root"
    {
        echo "topic=$topic"
        echo "session=$session"
        echo "user_id=$user_id"
        echo "base_url=$base_url"
    } > "$session_root/.ssafy_session_root" 2>/dev/null || true

    local first_repo="${topic}_ws_${session}_1"
    if [ -d "$first_repo" ]; then
        _open_repo_file "$first_repo"
    elif [ "${#cloned[@]}" -gt 0 ]; then
        _open_repo_file "${cloned[0]}"
    elif [ "${#skipped[@]}" -gt 0 ]; then
        _open_repo_file "${skipped[0]}"
    else
        if type ui_warn >/dev/null 2>&1; then
            ui_warn "No repository available to open."
        else
            echo "No repository to open."
        fi
    fi
}

ssafy_gitup() {
    init_algo_config

    # 필수 설정 가드: SSAFY_USER_ID, 커밋 접두사, 브랜치 미설정 시 차단
    _ssafy_require_config ssafy_user_id git_prefix git_branch || return 1

    local session_root=""
    session_root=$(_find_ssafy_session_root "$(pwd)" 2>/dev/null || true)
    if [ -z "$session_root" ]; then
        session_root="$(pwd)"
    fi
    export SSAFY_SESSION_ROOT="$session_root"

    local ssafy_mode=false
    local input=""
    local mode=""

    if [ $# -eq 0 ]; then
        if _is_interactive && type _ssafy_gitup_prompt_flow >/dev/null 2>&1; then
            _ssafy_gitup_prompt_flow
            local flow_rc=$?
            _gitup_debug_log "flow_end rc=$flow_rc mode=${SSAFY_GITUP_FLOW_MODE:-} input=${SSAFY_GITUP_FLOW_INPUT:-} source=${ALGO_ROOT_DIR:-unknown}"
            case "$flow_rc" in
                0)
                    input="$SSAFY_GITUP_FLOW_INPUT"
                    mode="$SSAFY_GITUP_FLOW_MODE"
                    if [ "$mode" = "3" ]; then
                        ssafy_mode=true
                    fi
                    ;;
                10|20)
                    _gitup_debug_log "top_level_cancel rc=$flow_rc (10=back, 20=cancel)"
                    if type ui_warn >/dev/null 2>&1; then
                        ui_warn "Canceled by user."
                    else
                        echo "[WARN] Canceled by user."
                    fi
                    return 1
                    ;;
                *)
                    echo "Usage: gitup <git-url | ssafy-topic | smart-link>"
                    return 1
                    ;;
            esac
        else
            echo "Usage: gitup <git-url | ssafy-topic | smart-link>"
            echo "Examples:"
            echo "  gitup https://github.com/user/repo.git"
            echo "  gitup data_ws_4"
            echo "  gitup --ssafy data_ws_4"
            return 1
        fi
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --ssafy|-s)
                ssafy_mode=true
                ;;
            *)
                if [[ "$1" == *"|"* ]]; then
                    local raw="$1"
                    local url="${raw%%|*}"
                    local token="${raw#*|}"

                    if [ -z "$input" ]; then
                        input="$url"
                    fi

                    if [ -n "$token" ]; then
                        local decoded=""
                        # SmartLink token: base64("Bearer ...") preferred, plain Bearer also supported
                        decoded=$(echo "$token" | base64 -d 2>/dev/null || echo "")
                        if [ -z "$decoded" ]; then
                            decoded=$(echo "$token" | base64 -D 2>/dev/null || echo "")
                        fi
                        decoded="${decoded//$'\r'/}"
                        if [[ "$decoded" != "Bearer "* ]] && [[ "$token" == "Bearer "* ]]; then
                            decoded="$token"
                        fi
                        if [[ "$decoded" == "Bearer "* ]]; then
                            export SSAFY_AUTH_TOKEN="$decoded"
                            if type ui_ok >/dev/null 2>&1; then
                                ui_ok "SmartLink token applied to current session."
                            else
                                echo "[OK] SmartLink token applied to current session."
                            fi
                        fi
                    fi
                    input="$url"
                else
                    echo "Usage: gitup <git-url | ssafy-topic | smart-link>"
                    return 1
                fi
                ;;
        esac
        shift
    done

    # Normalize SmartLink input for both interactive-flow and argv paths.
    if [[ "$input" == *"|"* ]]; then
        local raw="$input"
        local url="${raw%%|*}"
        local token="${raw#*|}"

        if _ssafy_git_is_valid_url "$url"; then
            input="$url"
        fi

        if [ -n "$token" ]; then
            local decoded=""
            decoded=$(echo "$token" | base64 -d 2>/dev/null || echo "")
            if [ -z "$decoded" ]; then
                decoded=$(echo "$token" | base64 -D 2>/dev/null || echo "")
            fi
            decoded="${decoded//$'\r'/}"
            if [[ "$decoded" != "Bearer "* ]] && [[ "$token" == "Bearer "* ]]; then
                decoded="$token"
            fi
            if [[ "$decoded" == "Bearer "* ]]; then
                export SSAFY_AUTH_TOKEN="$decoded"
                _gitup_debug_log "smartlink_token_applied len=${#decoded}"
            fi
        fi
    fi

    if [ -z "$input" ]; then
        echo "Usage: gitup <git-url | ssafy-topic | smart-link>"
        return 1
    fi

    if type ui_panel_begin >/dev/null 2>&1; then
        ui_panel_begin "gitup" "Input validation and clone run"
        if [ "$ssafy_mode" = true ]; then
            ui_info "input_mode=topic"
        elif [[ "$input" == *"|"* ]]; then
            ui_info "input_mode=smartlink"
        elif _ssafy_git_is_valid_url "$input"; then
            ui_info "input_mode=url"
        else
            ui_info "input_mode=auto"
        fi
        ui_info "input=$input"
    fi

    if [[ "$input" == https://project.ssafy.com/* ]]; then
        if type ui_step >/dev/null 2>&1; then
            ui_step "Run clone with Smart Batch flow"
        fi
        ssafy_batch "$input"
        return $?
    fi

    if [ "$ssafy_mode" = true ] || _ssafy_git_is_valid_topic "$input" || [[ "$input" =~ ^https?://lab\.ssafy\.com/ ]]; then
        if type ui_step >/dev/null 2>&1; then
            ui_step "Run clone with SSAFY topic flow"
        fi
        _gitup_ssafy "$input" || return 1
        return 0
    fi

    if ! _ssafy_git_is_valid_url "$input"; then
        if type ui_error >/dev/null 2>&1; then
            ui_error "Invalid input. Use http(s) URL or --ssafy topic format."
        else
            echo "[ERROR] Invalid input. URL must start with http(s) or use --ssafy with topic format."
        fi
        return 1
    fi

    if type ui_step >/dev/null 2>&1; then
        ui_step "Clone repository"
    else
        echo "[STEP] clone repository"
    fi
    git clone "$input" || return 1

    local repo_name
    repo_name=$(basename "$input" .git)

    if type ui_ok >/dev/null 2>&1; then
        ui_ok "clone completed: $repo_name"
    else
        echo "[OK] clone completed: $repo_name"
    fi

    _open_repo_file "$repo_name"
}
ssafy_batch() {
    if [ $# -eq 0 ]; then
        echo "Usage: ssafy_batch <URL> [COUNT=7]"
        echo "Example: ssafy_batch \"https://project.ssafy.com/.../PR00147645/...\" 7"
        return 1
    fi
    
    
    # [Fix V8.1] Prevent overwriting session token with empty value from config
    local current_token="$SSAFY_AUTH_TOKEN"
    
    if [ -f "$ALGO_CONFIG_FILE" ]; then
        source "$ALGO_CONFIG_FILE"
    fi
    
    # Restore session token if it was set
    if [ -n "$current_token" ]; then
        export SSAFY_AUTH_TOKEN="$current_token"
    fi
    
    if [ -n "$SSAFY_AUTH_TOKEN" ] && [[ "$SSAFY_AUTH_TOKEN" != "Bearer your_token_here" ]]; then
        export SSAFY_AUTH_TOKEN
    fi
    
    # Resolve helper script directory
    local script_dir="${ALGO_ROOT_DIR:-$HOME/.ssafy-tools}"

    # Python script location check
    if [ ! -f "$script_dir/ssafy_batch_create.py" ]; then
        if [ -f "$HOME/.ssafy-tools/ssafy_batch_create.py" ]; then
            script_dir="$HOME/.ssafy-tools"
        elif [ -f "$HOME/Desktop/SSAFY_sh_func/ssafy_batch_create.py" ]; then
            script_dir="$HOME/Desktop/SSAFY_sh_func"
        else
            echo "[error] runner not found: ssafy_batch_create.py"
            return 1
        fi
    fi
    
    local py_cmd
    if type _ssafy_python_lookup >/dev/null 2>&1; then
        py_cmd=$(_ssafy_python_lookup)
    else
        py_cmd="python3" # Fallback
    fi
    
    if [ -n "$py_cmd" ]; then
         # [Fix V8.1] Capture output and clone, generate session files
         local first_repo=""
         
         # Session files (.ssafy_session_meta, .ssafy_playlist, .ssafy_session_root)
         local ssafy_root="${SSAFY_SESSION_ROOT:-$(pwd)}"
         if [ -z "$ssafy_root" ] || [ ! -d "$ssafy_root" ]; then
             ssafy_root="$(pwd)"
         fi
         
         local original_dir="$(pwd)"
         cd "$ssafy_root" || return 1
         
         local playlist_file="$ssafy_root/.ssafy_playlist"
         local progress_file="$ssafy_root/.ssafy_progress"
         local meta_file="$ssafy_root/.ssafy_session_meta"
         
         # Reset session files
         rm -f "$playlist_file" "$progress_file" "$meta_file"
         
         while IFS='|' read -r url course_id pr_id pa_id; do
             # Remove CR for Windows compatibility
             url=$(echo "$url" | tr -d '\r')
            course_id=$(echo "$course_id" | tr -d '\r')
              
             if [ -n "$url" ]; then
                 if type ui_step >/dev/null 2>&1; then
                     ui_step "Processing URL: $url"
                 else
                     echo "Cloning: $url"
                 fi
                 git clone "$url"
                 
                 local folder_name=$(basename "$url" .git)
                 
                 # 1. Update Playlist
                 echo "$folder_name" >> "$playlist_file"
                 
                 # 2. Update Meta (Header & Item)
                 if [ ! -f "$meta_file" ]; then
                     local enc_course_id=$(echo -n "$course_id" | base64)
                     local created_at=$(date +"%Y%m%d%H%M%S")
                     {
                        # Store course_id as base64
                        # Keep plaintext course_id only for compatibility
                         echo "course_id=$enc_course_id"
                         echo "created_at=$created_at"
                     } > "$meta_file"
                 fi
                 
                 local enc_pr=$(echo -n "$pr_id" | base64)
                 local enc_pa=$(echo -n "$pa_id" | base64)
                 {
                     echo "$folder_name"
                     echo "$enc_pr"
                     echo "$enc_pa"
                 } >> "$meta_file"
                 
                 # 3. Update Progress (List Init)
                 _ssafy_progress_set "$ssafy_root" "$folder_name" "init"
                 
                 if [ -z "$first_repo" ]; then
                     first_repo="$folder_name"
                 fi
             fi
         done < <(echo "$SSAFY_AUTH_TOKEN" | "$py_cmd" "$script_dir/ssafy_batch_create.py" "$1" "$2" --pipe)
          
         if [ -n "$first_repo" ]; then
             if type ui_step >/dev/null 2>&1; then
                 ui_step "Open first repository: $first_repo"
             else
                 echo "Opening first repository: $first_repo"
             fi
             # [Fix V8.1] Sync status immediately (chk done)
             _sync_playlist_status "$ssafy_root"
             _open_repo_file "$first_repo"
         fi
    else
         if type ui_error >/dev/null 2>&1; then
             ui_error "Python runtime not found."
         else
             echo "[ERROR] Python command not found."
         fi
         return 1
    fi
}
