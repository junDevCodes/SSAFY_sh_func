# =============================================================================
# lib/git.sh
# Git Workflow & SSAFY Automation
# =============================================================================

_find_ssafy_session_root() {
    local start_dir="${1:-$(pwd)}"
    local dir="$start_dir"

    while true; do
        if [ -f "$dir/.ssafy_session_root" ]; then
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

_confirm_commit_message() {
    local msg="$1"
    local answer=""

    CONFIRMED_COMMIT_MSG=""

    while true; do
        echo "✅ 커밋 메시지: $msg"
        read -r -p "이대로 커밋하고 push할까요? (y/n): " answer
        case "$answer" in
            y|Y)
                CONFIRMED_COMMIT_MSG="$msg"
                return 0
                ;;
            n|N)
                read -r -p "커밋 메시지 다시 입력: " msg
                if [ -z "${msg//[[:space:]]/}" ]; then
                    echo "❗ 커밋 메시지가 비어 있습니다."
                    return 1
                fi
                ;;
            *)
                echo "❗ y 또는 n을 입력하세요."
                ;;
        esac
    done
}

_handle_git_commit() {
    local target_path="$1"
    local problem="$2"
    local custom_msg="$3"
    local lang="$4"
    
    local original_dir=$(pwd)
    
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
        echo "⚠️  Git 저장소를 찾을 수 없습니다"
        return
    fi
    
    cd "$git_root" || return
    
    local py_cmd
    if type _ssafy_python_lookup >/dev/null 2>&1; then
        py_cmd=$(_ssafy_python_lookup)
    else
        py_cmd="python3" # Fallback
    fi
    
    local relative_path=$(realpath --relative-to="$git_root" "$target_path" 2>/dev/null || \
        "$py_cmd" -c "import os.path; print(os.path.relpath('$target_path', '$git_root'))")
    
    echo "✅ Git 저장소: $git_root"
    echo "📁 대상: $relative_path"
    
    local relative_dir=$(dirname "$relative_path")
    git add "$relative_dir"
    
    local commit_msg=""
    if [ -n "$custom_msg" ]; then
        _confirm_commit_message "$custom_msg" || return 1
        commit_msg="$CONFIRMED_COMMIT_MSG"
    else
        local lang_label="Python"
        if [ "$lang" = "cpp" ]; then
            lang_label="C++"
        fi
        commit_msg="${GIT_COMMIT_PREFIX}: ${problem} ${lang_label}"
    fi
    
    if git commit -m "$commit_msg" 2>/dev/null; then
        echo "✅ 커밋 완료: $commit_msg"
        
        if [ "$GIT_AUTO_PUSH" = true ]; then
            local current_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)
            
            if git push origin "$GIT_DEFAULT_BRANCH" 2>/dev/null; then
                echo "✅ 푸시 완료! (브랜치: $GIT_DEFAULT_BRANCH)"
            else
                if [ -n "$current_branch" ] && [ "$current_branch" != "$GIT_DEFAULT_BRANCH" ]; then
                    echo "⚠️  브랜치 '$GIT_DEFAULT_BRANCH'로 푸시 실패, 현재 브랜치 '$current_branch'로 시도 중..."
                    if git push origin "$current_branch" 2>/dev/null; then
                        echo "✅ 푸시 완료! (브랜치: $current_branch)"
                    else
                        echo "❌ 푸시 실패 (시도한 브랜치: $GIT_DEFAULT_BRANCH, $current_branch)"
                        echo "💡 'algo-config edit'로 브랜치명을 확인하거나 수동으로 푸시하세요"
                    fi
                else
                    echo "❌ 푸시 실패 (브랜치: $GIT_DEFAULT_BRANCH)"
                    echo "💡 'algo-config edit'로 브랜치명을 확인하거나 수동으로 푸시하세요"
                fi
            fi
        fi
    else
        echo "⚠️  커밋할 변경사항이 없습니다"
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
        xdg-open "$url" 2>/dev/null || echo "🔗 $url"
    fi
}

_show_submission_links() {
    local ssafy_root="$1"
    shift
    local folders=("$@")
    
    local meta_file="$ssafy_root/.ssafy_session_meta"
    if [ ! -f "$meta_file" ]; then
        return 0
    fi
    
    local course_id_enc=$(grep "^course_id_enc=" "$meta_file" 2>/dev/null | cut -d= -f2)
    local course_id=""

    if [ -n "$course_id_enc" ]; then
        course_id=$(echo "$course_id_enc" | base64 -d 2>/dev/null)
    else
        course_id=$(grep "^course_id=" "$meta_file" 2>/dev/null | cut -d= -f2)
    fi
    
    if [ -z "$course_id" ]; then
        return 0
    fi
    
    echo ""
    echo "📋 제출 링크 목록:"
    
    local i=1
    local has_link=false
    local urls=()
    
    for folder in "${folders[@]}"; do
        local pr_id_enc=$(grep "^${folder}_enc=" "$meta_file" 2>/dev/null | cut -d= -f2)
        local pr_id=""
        
        if [ -n "$pr_id_enc" ]; then
             pr_id=$(echo "$pr_id_enc" | base64 -d 2>/dev/null)
        else
             pr_id=$(grep "^$folder=" "$meta_file" 2>/dev/null | cut -d= -f2)
        fi
        
        if [ -z "$pr_id" ]; then
            pr_id=$(grep "^practice_id=" "$meta_file" 2>/dev/null | cut -d= -f2)
        fi
        
        local pa_id_enc=$(grep "^${folder}_pa_enc=" "$meta_file" 2>/dev/null | cut -d= -f2)
        local pa_id=""

        if [ -n "$pa_id_enc" ]; then
            pa_id=$(echo "$pa_id_enc" | base64 -d 2>/dev/null)
        else
            pa_id=$(grep "^${folder}_pa=" "$meta_file" 2>/dev/null | cut -d= -f2)
        fi
        
        if [ -n "$pr_id" ]; then
            local current_url=""
            if [ -n "$pa_id" ]; then
                 current_url="https://project.ssafy.com/practiceroom/course/${course_id}/practice/${pr_id}/answer/${pa_id}"
            else
                 current_url="https://project.ssafy.com/practiceroom/course/${course_id}/practice/${pr_id}/detail"
            fi
            echo "  $i. $folder: $current_url"
            urls+=("$current_url")
            has_link=true
        else
            echo "  $i. $folder: (링크 정보 없음)"
            urls+=("")
        fi
        ((i++))
    done
    
    if [ "$has_link" = false ]; then return 0; fi
    echo ""
    echo "👉 'a' → 전체 열기 | 번호 → 해당 링크 열기 | Enter → 종료"
    read -r choice
    
    if [ "$choice" = "a" ]; then
        echo "⏳ 브라우저를 열고 있습니다..."
        for url in "${urls[@]}"; do
            if [ -n "$url" ]; then
                _open_browser "$url"
                sleep 0.5 
            fi
        done
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#urls[@]} ]; then
        local idx=$((choice-1))
        local selected_url="${urls[$idx]}"
        if [ -n "$selected_url" ]; then
            _open_browser "$selected_url"
        else
            echo "❌ 해당 항목은 링크가 없습니다."
        fi
    fi
}

_open_repo_file() {
    local repo_dir="$1"

    if [ ! -d "$repo_dir" ]; then
        echo "??  디렉터리를 찾을 수 없습니다: $repo_dir"
        return 1
    fi

    cd "$repo_dir" || return 1

    local editor
    editor=$(get_active_ide)

    local maxdepth=6
    local -a primary_files=()

    while IFS= read -r -d '' f; do
        f="${f#./}"
        primary_files+=("$f")
    done < <(
        find . -maxdepth "$maxdepth" \
            \( -path './.git' -o -path './.git/*' -o -path './.vscode' -o -path './.vscode/*' -o -path './.idea' -o -path './.idea/*' -o -path './node_modules' -o -path './node_modules/*' -o -path './venv' -o -path './venv/*' -o -path './.venv' -o -path './.venv/*' -o -path './__pycache__' -o -path './__pycache__/*' \) -prune -o \
            -type f \( -name '*.py' -o -name '*.ipynb' -o -name '*.cpp' -o -name '*.vue' -o -name '*.js' -o -name '*.html' -o -name '*.css' -o -name '*.java' \) -print0 2>/dev/null
    )

    local chosen=""

    if _is_interactive; then
        while true; do
            echo ""
            echo "============================================================"
            echo " 📂 [Code Selector] 자주 사용하는 파일"
            echo "============================================================"
            if [ "${#primary_files[@]}" -gt 0 ]; then
                local i=""
                for i in "${!primary_files[@]}"; do
                    printf "  %2d. %s\n" "$((i + 1))" "${primary_files[$i]}"
                done
            else
                echo "  (추천 파일 없음)"
            fi

            echo "------------------------------------------------------------"
            echo "  t. 🌳 전체 파일 트리 보기"
            echo "  q. ❌ 취소"
            echo "============================================================"

            local choice=""
            read -r -p "👉 원하시는 파일 번호 또는 메뉴를 입력하세요: " choice

            if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
                return 1
            fi

            if [ "$choice" = "t" ] || [ "$choice" = "T" ]; then
                local -a all_files=()
                while IFS= read -r -d '' af; do
                    af="${af#./}"
                    case "$af" in
                        .git/*|.git|.vscode/*|.idea/*|node_modules/*|venv/*|.venv/*|__pycache__/*) continue ;;
                        *.iml|*.code-workspace|.DS_Store) continue ;;
                        .gitignore|.gitattributes|.editorconfig|.env|.env.*) continue ;;
                    esac
                    all_files+=("$af")
                done < <(
                    find . -maxdepth "$maxdepth" \
                        \( -path './.git' -o -path './.git/*' -o -path './node_modules' -o -path './node_modules/*' -o -path './venv' -o -path './venv/*' -o -path './.venv' -o -path './.venv/*' \) -prune -o \
                        -type f -print0 2>/dev/null
                )

                if [ "${#all_files[@]}" -eq 0 ]; then
                    echo "⚠️  열 수 있는 파일을 찾을 수 없습니다."
                    continue
                fi

                echo ""
                echo "============================================================"
                echo " 🌳 [File Tree] 전체 파일 목록"
                echo "============================================================"
                local j=""
                for j in "${!all_files[@]}"; do
                    printf "  %2d. %s\n" "$((j + 1))" "${all_files[$j]}"
                done
                echo "------------------------------------------------------------"
                echo "  b. 🔙 뒤로 가기"
                echo "  q. ❌ 취소"
                echo "============================================================"

                local tchoice=""
                read -r -p "👉 번호를 입력하세요: " tchoice

                if [ "$tchoice" = "q" ] || [ "$tchoice" = "Q" ]; then
                    return 1
                fi
                if [ "$tchoice" = "b" ] || [ "$tchoice" = "B" ]; then
                    continue
                fi
                if [[ "$tchoice" =~ ^[0-9]+$ ]] && [ "$tchoice" -ge 1 ] && [ "$tchoice" -le "${#all_files[@]}" ]; then
                    chosen="${all_files[$((tchoice - 1))]}"
                    break
                fi

                echo "⚠️  잘못된 선택입니다."
                continue
            fi

            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#primary_files[@]}" ]; then
                chosen="${primary_files[$((choice - 1))]}"
                break
            fi

            echo "⚠️  잘못된 선택입니다."
        done
    else
        if [ "${#primary_files[@]}" -gt 0 ]; then
            chosen="${primary_files[0]}"
        else
            chosen="$(find . -maxdepth 2 -type f | head -n 1)"
            chosen="${chosen#./}"
        fi
    fi

    if [ -n "$chosen" ] && [ -f "$chosen" ]; then
        echo "📌 감지된 IDE: $editor"
        echo "🎉 에디터에서 파일 열기: $chosen"
        _open_in_editor "$editor" "$chosen"
    else
        echo "⚠️  열 파일을 찾을 수 없습니다"
        echo "📋 클론된 폴더 내용:"
        ls -la
    fi

    echo "✅ 프로젝트 준비 완료!"
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
                 echo "${folder}=done" >> "$progress_file"
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
    
    for folder in "${all_folders[@]}"; do
        if ! grep -q "^${folder}=done" "$progress_file" 2>/dev/null; then
            unsolved+=("$folder")
        fi
    done
    
    if [ ${#unsolved[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  아직 완료되지 않은 문제가 있습니다:"
        local i=1
        for folder in "${unsolved[@]}"; do
            echo "  $i. $folder"
            ((i++))
        done
        echo ""
        echo "👉 번호 입력 시 해당 폴더로 이동 | Enter → 종료"
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#unsolved[@]} ]; then
            local selected="${unsolved[$((choice-1))]}"
            echo "➡️  $selected 로 이동합니다."
            _open_repo_file "$ssafy_root/$selected"
        fi
    else
        echo ""
        echo "🎉 모든 문제를 완료했습니다! 고생하셨습니다!"
        _show_submission_links "$ssafy_root" "${all_folders[@]}"
        return 0 
    fi
    return 1 
}

_gitdown_all() {
    local ssafy_root=""
    ssafy_root=$(_find_ssafy_session_root "$(pwd)" 2>/dev/null || true)
    
    if [ -z "$ssafy_root" ] && [ -n "${SSAFY_SESSION_ROOT:-}" ] && [ -d "$SSAFY_SESSION_ROOT" ]; then
        ssafy_root="$SSAFY_SESSION_ROOT"
    fi
    
    if [ -z "$ssafy_root" ]; then
        echo "❌ SSAFY 세션 루트를 찾을 수 없습니다."
        echo "💡 gitup으로 실습실을 먼저 생성하세요."
        return 1
    fi
    
    cd "$ssafy_root" || return 1
    echo "📂 세션 루트: $ssafy_root"
    
    local folders=()
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
        echo "⚠️  처리할 폴더가 없습니다."
        return 0
    fi
    
    echo "📋 처리할 폴더: ${#folders[@]}개"
    echo ""
    
    local success_count=0
    local fail_count=0
    local skip_count=0
    local progress_file="$ssafy_root/.ssafy_progress"
    local pushed_folders=()
    
    for folder in "${folders[@]}"; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📁 [$folder]"
        
        cd "$ssafy_root/$folder" || {
            echo "  ❌ 폴더 이동 실패"
            ((fail_count++))
            continue
        }
        
        if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
            echo "  ⏭️  변경사항 없음 (스킵)"
            ((skip_count++))
            cd "$ssafy_root"
            continue
        fi
        
        git add .
        if git commit -m "${GIT_COMMIT_PREFIX:-solve}: $folder" 2>/dev/null; then
            if git push 2>/dev/null; then
                echo "  ✅ 푸시 완료"
                ((success_count++))
                pushed_folders+=("$folder")
                echo "$folder=done" >> "$progress_file"
            else
                echo "  ❌ 푸시 실패"
                ((fail_count++))
            fi
        else
            echo "  ⚠️  커밋 실패 (이미 커밋됨?)"
            ((skip_count++))
        fi
        
        cd "$ssafy_root"
    done
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 결과: ✅ ${success_count} 성공 | ❌ ${fail_count} 실패 | ⏭️ ${skip_count} 스킵"
    
    _check_unsolved_folders "$ssafy_root" "${folders[@]}"
    local playlist_complete=$?
    
    if [ "$playlist_complete" -ne 0 ] && [ ${#pushed_folders[@]} -gt 0 ]; then
        _show_submission_links "$ssafy_root" "${pushed_folders[@]}"
    fi
}

ssafy_gitdown() {
    init_algo_config
    
    for arg in "$@"; do
        if [ "$arg" = "--all" ] || [ "$arg" = "-a" ] || [ "$arg" = "-all" ]; then
            _gitdown_all
            return $?
        fi
    done
    
    echo "🔍 현재 Git 상태:"
    git status --short
    echo ""
    
    local commit_msg=""
    local custom_msg=false
    local ssafy_mode=false
    local push_ok=false
    local current_repo=$(basename "$(pwd)" 2>/dev/null)

    if [[ "$current_repo" =~ ^[A-Za-z0-9]+_(ws|hw|ex)(_[0-9]+(_[0-9]+)?)?$ ]]; then
        if [ "$ssafy_mode" = false ]; then
            ssafy_mode=true
            echo "✨ SSAFY 폴더 감지: 자동 모드 활성화"
        fi
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --ssafy|-s) ssafy_mode=true ;;
            --msg|-m)
                shift
                if [ -z "$1" ] || [[ "$1" == --* ]]; then
                    echo "❗ --msg 옵션에는 커밋 메시지가 필요합니다."
                    return 1
                fi
                commit_msg="$1"
                custom_msg=true
                ;;
            --msg=*)
                commit_msg="${1#--msg=}"
                if [ -z "$commit_msg" ]; then
                    echo "❗ --msg 옵션에는 커밋 메시지가 필요합니다."
                    return 1
                fi
                custom_msg=true
                ;;
            *)
                if [ -z "$commit_msg" ] && [[ "$1" != --* ]]; then
                    commit_msg="$1"
                    custom_msg=true
                else
                    echo "❗ 커밋 메시지에 공백이 있으면 따옴표로 감싸주세요."
                    echo "   예: gitdown \"feat: new commit\""
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [ "$custom_msg" = true ]; then
        if [ -z "${commit_msg//[[:space:]]/}" ]; then
            echo "❗ 커밋 메시지가 비어 있습니다."
            return 1
        fi
        _confirm_commit_message "$commit_msg" || return 1
        commit_msg="$CONFIRMED_COMMIT_MSG"
    else
        if [ -z "$current_repo" ] || [ "$current_repo" = "/" ] || [ "$current_repo" = "\\" ]; then
            current_repo="update"
        fi
        commit_msg="${GIT_COMMIT_PREFIX}: $current_repo"
    fi

    git add .
    
    echo "📌 커밋 메시지: $commit_msg"
    if git commit -m "$commit_msg"; then
        echo "✅ 커밋 완료"
        
        if [ "$GIT_AUTO_PUSH" = true ]; then
            echo "🌐 원격 저장소로 푸시 중..."
            
            local branches=$(git branch --list 2>/dev/null | sed 's/^[* ] //' | tr '\n' ' ')
            local has_master=false
            local has_main=false
            local push_branch=""
            local remote_head=""
            local need_select=true

            for branch in $branches; do
                if [ "$branch" = "master" ]; then has_master=true; fi
                if [ "$branch" = "main" ]; then has_main=true; fi
            done

            remote_head=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
            if [ -z "$remote_head" ]; then
                remote_head=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
            fi
            
            # Smart Branch Selection
            if [ -n "$remote_head" ]; then
                if [ "$has_master" = true ] && [ "$has_main" = true ]; then need_select=true;
                elif [ "$has_master" = false ] && [ "$has_main" = false ]; then need_select=true;
                elif [ "$remote_head" = "master" ] && [ "$has_master" = true ] && [ "$has_main" = false ]; then
                    push_branch="$remote_head"; need_select=false;
                elif [ "$remote_head" = "main" ] && [ "$has_main" = true ] && [ "$has_master" = false ]; then
                    push_branch="$remote_head"; need_select=false;
                else need_select=true; fi
            else
                need_select=true
            fi

            if [ "$need_select" = true ]; then
                echo ""
                echo "📋 사용 가능한 브랜치:"
                local branch_list=$(git branch --list 2>/dev/null | sed 's/^[* ] //')
                local branch_array=()
                local index=1
                
                while IFS= read -r branch; do
                    if [ -n "$branch" ]; then
                        echo "  $index) $branch"
                        branch_array[$index]="$branch"
                        index=$((index + 1))
                    fi
                done <<< "$branch_list"
                
                if [ $index -eq 1 ]; then
                    echo "❌ 사용 가능한 브랜치가 없습니다. 푸시를 건너뜁니다."
                    return 0
                fi
                
                echo ""
                read -p "푸시할 브랜치 번호를 선택하세요 (1-$((index-1))): " branch_choice
                
                if [ -n "$branch_choice" ] && [ "$branch_choice" -ge 1 ] && [ "$branch_choice" -lt "$index" ] 2>/dev/null; then
                    push_branch="${branch_array[$branch_choice]}"
                else
                    echo "❌ 잘못된 선택입니다. 푸시를 건너뜁니다."
                    return 0
                fi
            fi
            
            if [ -n "$push_branch" ]; then
                echo "🚀 브랜치 '$push_branch'로 푸시 중..."
                if git push origin "$push_branch" 2>/dev/null; then
                    echo "✅ 푸시 완료! (브랜치: $push_branch)"
                    push_ok=true
                else
                    echo "❌ 푸시 실패 (브랜치: $push_branch)"
                    echo "💡 수동으로 푸시하세요: git push origin $push_branch"
                fi
            fi
        fi
    else
        echo "⚠️  커밋 실패"
        return 1
    fi
    
    echo "📁 상위 폴더로 이동"
    cd .. || {
        echo "⚠️  상위 폴더로 이동할 수 없습니다"
        return 1
    }

    if [ "$ssafy_mode" = true ]; then
        local ssafy_root=""
        ssafy_root=$(_find_ssafy_session_root "$(pwd)" 2>/dev/null || true)
        if [ -z "$ssafy_root" ] && [ -n "${SSAFY_SESSION_ROOT:-}" ] && [ -d "$SSAFY_SESSION_ROOT" ]; then
            ssafy_root="$SSAFY_SESSION_ROOT"
        fi
        if [ -n "$ssafy_root" ]; then
            cd "$ssafy_root" || {
                echo "⚠️  SSAFY 루트로 이동할 수 없습니다: $ssafy_root"
                return 1
            }
        fi
    fi

    if [ "$ssafy_mode" = true ]; then
        if [ "$push_ok" = true ]; then
            if [ -n "$ssafy_root" ] && [ -f "$ssafy_root/.ssafy_progress" ]; then
                 if ! grep -q "^${current_repo}=done" "$ssafy_root/.ssafy_progress" 2>/dev/null; then
                     echo "${current_repo}=done" >> "$ssafy_root/.ssafy_progress"
                 fi
            fi

            _show_submission_links "$(pwd)" "$current_repo"
            
            local next_repo=$(_ssafy_next_repo "$current_repo")
            if [ -n "$next_repo" ] && [ ! -d "$next_repo" ]; then
                echo "⚠️  다음 문제 레포가 로컬에 없습니다: $next_repo"
                echo "💡  SSAFY에서 실습실/과제를 생성해야 레포가 만들어질 수 있습니다."
            fi
            if [ -n "$next_repo" ] && [ -d "$next_repo" ]; then
                echo "➡️  다음 문제로 이동: $next_repo"
                _open_repo_file "$next_repo" || echo "⚠️  다음 디렉터리로 이동할 수 없습니다: $next_repo"
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
                else
                    if [[ "$current_repo" =~ ^([A-Za-z0-9]+)_(ws|hw|ex)_([0-9]+)(_[0-9]+)?$ ]]; then
                        local topic="${BASH_REMATCH[1]}"
                        local session="${BASH_REMATCH[3]}"
                        echo ""
                        echo "🎉 [${topic}] 과목의 해당 [${session}]차시가 종료되었습니다. 고생하셨습니다"
                    else
                        echo "⚠️  다음 문제를 찾을 수 없습니다."
                    fi
                fi
            fi
        else
            echo "⚠️  푸시 실패/미실행으로 다음 문제 이동을 건너뜁니다."
        fi
    fi
}

_gitup_ssafy() {
    local input="$1"

    _ensure_ssafy_config
    if [ -z "${SSAFY_BASE_URL:-}" ] || [ -z "${SSAFY_USER_ID:-}" ]; then
        echo "⚠️  SSAFY 설정이 필요합니다. 'algo-config edit'로 SSAFY_BASE_URL/SSAFY_USER_ID를 설정하세요."
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
        read -r -p "차시 입력: " session
    elif [[ "$repo_name" =~ ^([A-Za-z0-9]+)$ ]]; then
        topic="$repo_name"
        read -r -p "차시 입력: " session
    else
        if [[ "$repo_name" =~ ^(ws|hw|ex)_[0-9]+(_[0-9]+)?$ ]]; then
            echo "?? SSAFY 입력 형식이 올바르지 않습니다: $repo_name"
            echo "   예: <topic>_ws_<차시> 또는 <topic>_ws_<차시>_<번호>"
            echo "   예: ds_ws_2 또는 ds_ws_2_1"
        fi
        return 1
    fi

    if [ -z "$session" ] || ! [[ "$session" =~ ^[0-9]+$ ]]; then
        echo "❗ 차시 번호가 올바르지 않습니다."
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

    echo "Clone summary: ok=${#cloned[@]}, skipped=${#skipped[@]}, failed=${#failed[@]}"
    if [ "${#failed[@]}" -gt 0 ]; then
        echo "Failed: ${failed[*]}"
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
        echo "No repository to open."
    fi
}

ssafy_gitup() {
    init_algo_config
    local ssafy_mode=false
    local input=""

    if [ $# -eq 0 ]; then
        echo "🔐 [Secure Mode] Smart Link(URL|Token) 또는 URL을 붙여넣으세요."
        echo "   (입력 내용은 화면에 표시되지 않습니다)"
        
        local prompt_input=$(_read_masked_input "👉 Paste Here (Ctrl+V + Enter): ")
        echo "" # 줄바꿈
        
        if [ -z "$prompt_input" ]; then
            echo "❌ 입력이 취소되었습니다."
            return 1
        fi
        set -- "$prompt_input"
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --ssafy|-s) ssafy_mode=true ;;
            *)
                if [[ "$1" == *"|"* ]]; then
                    local raw="$1"
                    local url="${raw%%|*}"
                    local token="${raw#*|}"
                    
                    if [ -z "$input" ]; then input="$url"; fi
                    
                    if [ -n "$token" ]; then
                        if [ -f "$ALGO_CONFIG_FILE" ]; then

                            local decoded=$(echo "$token" | base64 -d 2>/dev/null || echo "")
                            if [[ "$decoded" == "Bearer "* ]]; then
                                export SSAFY_AUTH_TOKEN="$decoded"
                                echo "🔐 [Smart Copy] 인증 토큰 자동 업데이트 완료"
                            fi
                        fi
                    fi
                elif [ -z "$input" ]; then
                    input="$1"
                else
                    echo "❗️사용법: gitup <git-repository-url | ssafy-topic>"
                    echo "예시:"
                    echo "  gitup https://github.com/user/repo.git"
                    echo "  gitup data_ws"
                    echo "  gitup https://lab.ssafy.com/${SSAFY_USER_ID}/data_ws_4_1"
                    echo "  gitup --ssafy data_ws"
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [ -z "$input" ]; then
        echo "❗️사용법: gitup <git-repository-url | ssafy-topic>"
        return 1
    fi

    local ssafy_detected=false
    if [ "$ssafy_mode" = true ]; then
        ssafy_detected=true
    elif [[ "$input" =~ ^https?://lab\.ssafy\.com/ ]]; then
        ssafy_detected=true
    fi

    if [[ "$input" == https://project.ssafy.com/* ]]; then
        ssafy_batch "$input"
        return $?
    fi

    if [[ "$input" =~ ^[A-Za-z0-9]+_(ws|hw)(_[0-9]+(_[0-9]+)?)?$ ]]; then
        _gitup_ssafy "$input" || return 1
        return 0
    fi
    
    echo "🔄 Git 저장소 클론 중: $input"
    git clone "$input" || return 1
    
    local repo_name=$(basename "$input" .git)
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
    
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # [Modularity Fix] algo_functions.sh가 아닌 lib/git.sh여도 상위의 ssafy_batch_create.py를 찾아야 함
    # 하지만 현재 구조에서는 lib/ 외부에 있을 수 있음.
    # algo_functions.sh가 로드된 위치를 기준?
    # 일단 현재 디렉토리 기준 상위(..) 체크
    if [ ! -f "$script_dir/ssafy_batch_create.py" ]; then
        # lib/ 안에 있는 경우 상위 체크
        if [ -f "$script_dir/../ssafy_batch_create.py" ]; then
            script_dir="$script_dir/.."
        elif [ -f "$HOME/Desktop/SSAFY_sh_func/ssafy_batch_create.py" ]; then
             script_dir="$HOME/Desktop/SSAFY_sh_func"
        fi
    fi

    if [ ! -f "$script_dir/ssafy_batch_create.py" ]; then
        echo "❌ 실행 오류: 'ssafy_batch_create.py' 파일을 찾을 수 없습니다."
        return 1
    fi
    
    local py_cmd
    if type _ssafy_python_lookup >/dev/null 2>&1; then
        py_cmd=$(_ssafy_python_lookup)
    else
        py_cmd="python3" # Fallback
    fi
    
    if [ -n "$py_cmd" ]; then
         # [Fix V8.1] Capture output and clone
         local first_repo=""
         
         while IFS='|' read -r url course_id pr_id pa_id; do
             # Remove CR for Windows compatibility
             url=$(echo "$url" | tr -d '\r')
             
             if [ -n "$url" ]; then
                 echo "⬇️  Cloning: $url"
                 git clone "$url"
                 
                 if [ -z "$first_repo" ]; then
                     first_repo=$(basename "$url" .git)
                 fi
             fi
         done < <(echo "$SSAFY_AUTH_TOKEN" | "$py_cmd" "$script_dir/ssafy_batch_create.py" "$1" "$2" --pipe)
         
         if [ -n "$first_repo" ]; then
             echo "📂 Opening first repository: $first_repo"
             _open_repo_file "$first_repo"
         fi
    else
         echo "❌ Python을 찾을 수 없습니다."
         return 1
    fi
}
