# =============================================================================
# lib/config.sh
# Configuration Management & Initialization
# =============================================================================


# 설정 파일 경로 정의 (Global)
# Phase 1 Task 1-1: 경로 통일 (.algo_config)
ALGO_CONFIG_FILE="$HOME/.algo_config"

init_algo_config() {
    if [ ! -f "$ALGO_CONFIG_FILE" ]; then
        echo "⚙️  설정 파일이 없어 새로 생성합니다: $ALGO_CONFIG_FILE"
        cat <<EOF > "$ALGO_CONFIG_FILE"
# SSAFY Algo Functions Config
ALGO_BASE_DIR="$HOME/algos"
GIT_DEFAULT_BRANCH="main"
GIT_COMMIT_PREFIX="solve"
GIT_AUTO_PUSH=true
IDE_EDITOR=""
SSAFY_BASE_URL="https://lab.ssafy.com"
SSAFY_USER_ID=""
# 토큰은 보안상 파일에 저장하지 않음 (세션 전용)
EOF
    fi

    # Load Config
    source "$ALGO_CONFIG_FILE"
    
    # [V7.6] 호환성: ALGO_BASE_DIR가 없으면 추가
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
    
    # [보안] 토큰은 파일에 저장하지 않음 (세션 전용)
    # - 문서(README) 정책과 실제 동작을 일치시키기 위한 가드
    # - 토큰 값은 환경변수로만 유지하고 설정 파일에는 기록하지 않는다
    if [ "$key" = "SSAFY_AUTH_TOKEN" ]; then
        export SSAFY_AUTH_TOKEN="$value"
        echo "🔐 토큰은 보안상 설정 파일에 저장하지 않습니다. (세션 전용)"
        return 0
    fi

    if [ ! -f "$ALGO_CONFIG_FILE" ]; then
        init_algo_config
    fi
    
    # 기존 키가 있으면 변경
    if grep -q "^${key}=" "$ALGO_CONFIG_FILE"; then
        # Phase 4 Task 4-2: sed 공통 함수 사용
        _sed_inplace "s|^${key}=.*|${key}=\"${value}\"|" "$ALGO_CONFIG_FILE"
    else
        # 없으면 추가
        echo "${key}=\"${value}\"" >> "$ALGO_CONFIG_FILE"
    fi
    
    # 환경변수 즉시 반영
    export "${key}=${value}"
}

# 설정 편집 명령어 (V7.6 네임스페이스)
ssafy_algo_config() {
    init_algo_config
    
    if [ "$1" = "edit" ]; then
        # V7.0: Python 마법사 사용
        # Phase 1 Task 1-3: ALGO_ROOT_DIR 사용
        # Phase 1 Task 1-4: readlink -f 호환성 수정 (macOS)
        local script_dir="${ALGO_ROOT_DIR:-$HOME/.ssafy-tools}"
        
        # Python 스크립트 파일 존재 확인
        if [ ! -f "$script_dir/algo_config_wizard.py" ]; then
            # 폴백: 다른 경로 시도
            if [ -f "$HOME/Desktop/SSAFY_sh_func/algo_config_wizard.py" ]; then
                script_dir="$HOME/Desktop/SSAFY_sh_func"
            elif [ -f "$HOME/.ssafy-tools/algo_config_wizard.py" ]; then
                script_dir="$HOME/.ssafy-tools"
            else
                echo "❌ algo_config_wizard.py를 찾을 수 없습니다."
                return 1
            fi
        fi
        
        python "$script_dir/algo_config_wizard.py"
        
        # [UX] 자동 적용 (엔터 없이 바로 적용)
        echo "🔄 변경된 설정을 적용 중입니다..."
        # ~/.bashrc가 있으면 source, 없으면 algo_functions.sh만 다시 로드?
        # 보통 사용자는 ~/.bashrc를 통해 로드하므로
        if [ -f "$HOME/.bashrc" ]; then
             source "$HOME/.bashrc"
        else
             init_algo_config
        fi
        
        echo "✅ 설정이 적용되었습니다!"
        return
    fi
    
    if [ "$1" = "show" ]; then
        echo "=================================================="
        echo " 🛠  SSAFY Algo Config (${ALGO_FUNCTIONS_VERSION})"
        echo "=================================================="
        echo ""
        
        echo "📂 [기본 설정]"
        echo "  • 작업 경로 : ${ALGO_BASE_DIR:-미설정}"
        echo ""
        
        echo "💻 [IDE 설정]"
        if [ -n "${IDE_EDITOR:-}" ]; then
            echo "  • 사용 IDE  : ${IDE_EDITOR}"
            # alias 등으로 잡혀있을 수 있으므로 type 사용이 나을 수도 있으나, command -v로 체크
            local ide_path=$(command -v "$IDE_EDITOR" 2>/dev/null || echo "❌ 연결 안됨 (자동 탐색 필요)")
            echo "  • 실행 경로 : $ide_path"
        else
            echo "  • 사용 IDE  : 미설정"
        fi
        echo ""
        
        echo "🐙 [Git 설정]"
        echo "  • 브랜치    : ${GIT_DEFAULT_BRANCH:-main}"
        echo "  • 접두어    : ${GIT_COMMIT_PREFIX:-solve}"
        echo "  • 자동푸시  : ${GIT_AUTO_PUSH:-true}"
        echo ""
        
        echo "🔑 [SSAFY 설정]"
        echo "  • 서버 URL  : ${SSAFY_BASE_URL:-https://lab.ssafy.com}"
        echo "  • 사용자 ID : ${SSAFY_USER_ID:-미설정}"
        if [ -n "${SSAFY_AUTH_TOKEN:-}" ]; then
             echo "  • 인증 토큰 : 🔐 설정됨 (세션 전용)"
        else
             echo "  • 인증 토큰 : ❌ 미설정"
        fi
        
        echo ""
        echo "=================================================="
        echo "💡 수정하려면: algo-config edit"
        echo "=================================================="
        return
    fi
    
    if [ "$1" = "reset" ]; then
        rm -f "$ALGO_CONFIG_FILE"
        init_algo_config
        echo "✅ 설정이 초기화되었습니다"
        return
    fi
    
    echo "사용법:"
    echo "  algo-config edit   - 설정 파일 편집"
    echo "  algo-config show   - 현재 설정 보기"
    echo "  algo-config reset  - 설정 초기화"
}
