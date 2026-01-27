# =============================================================================
# lib/update.sh
# Update & Version Checking Logic
# =============================================================================

# 업데이트 명령어 (V7.6 네임스페이스)
ssafy_algo_update() {
    # Phase 1 Task 1-3: ALGO_ROOT_DIR 사용
    local script_dir="${ALGO_ROOT_DIR:-$HOME/.ssafy-tools}"
    
    echo "📍 설치 경로: $script_dir"
    echo "🔄 최신 버전으로 업데이트 중..."
    
    if [ ! -d "$script_dir/.git" ]; then
        echo "❌ Git 저장소가 아닙니다. 수동으로 다시 설치해주세요."
        return 1
    fi
    
    (
        cd "$script_dir" || exit 1
        # 로컬 변경사항 과감히 버리고 강제 동기화 (사용자 수정 방지)
        git fetch --all
        git reset --hard origin/main
    )
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ 업데이트 완료! (V7.6+)"
        echo "   변경사항을 적용하려면 새 터미널을 열거나 'source ~/.bashrc'를 실행하세요."
        echo ""
        read -r -p "🚀 지금 셸을 재시작하시겠습니까? (y/N): " restart_choice
        if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
            exec bash
        fi
    else
        echo "❌ 업데이트 실패. 네트워크 상태를 확인하거나 재설치해주세요."
    fi
}

# 업데이트 알림 체크 (하루 1회, 백그라운드)
ALGO_UPDATE_CHECK_FILE="$HOME/.algo_update_last_check"

_check_update() {
    # Phase 1 Task 1-3: ALGO_ROOT_DIR 사용
    local script_dir="${ALGO_ROOT_DIR:-$HOME/.ssafy-tools}"
    
    # .git 디렉토리가 없으면 패스
    if [ ! -d "$script_dir/.git" ]; then
        return 0
    fi

    # 하루에 한 번만 체크
    if [ -f "$ALGO_UPDATE_CHECK_FILE" ]; then
        local last_check
        last_check=$(cat "$ALGO_UPDATE_CHECK_FILE" 2>/dev/null || echo 0)
        local current_time
        current_time=$(date +%s)
        local diff=$((current_time - last_check))
        
        # 86400초 = 24시간
        if [ $diff -lt 86400 ]; then
            return 0
        fi
    fi

    # 백그라운드에서 체크
    if command -v git > /dev/null 2>&1; then
        (
            cd "$script_dir" || exit
            # timeout 명령어가 있으면 사용, 없으면 그냥 실행 (백그라운드이므로)
            if command -v timeout > /dev/null 2>&1; then
                git_cmd="timeout 2s git fetch origin main"
            else
                git_cmd="git fetch origin main"
            fi
            
            if $git_cmd > /dev/null 2>&1; then
                local local_hash remote_hash
                local_hash=$(git rev-parse HEAD 2>/dev/null)
                remote_hash=$(git rev-parse origin/main 2>/dev/null)
                
                if [ -n "$local_hash" ] && [ -n "$remote_hash" ] && [ "$local_hash" != "$remote_hash" ]; then
                    echo ""
                    echo "📦 [Update] 새로운 버전이 있습니다! (현재: ${ALGO_FUNCTIONS_VERSION:-Unknown})"
                    echo "   👉 'algo-update'를 실행하여 업데이트하세요."
                    echo ""
                fi
                # 체크 시간 기록
                date +%s > "$ALGO_UPDATE_CHECK_FILE"
            fi
        ) &
        disown 2>/dev/null || true  # 백그라운드 작업 완료 메시지 억제 (비대화형 쉘 호환)
    fi
}
