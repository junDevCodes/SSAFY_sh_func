#!/bin/bash
# =============================================================================
# SSAFY Shell Functions 자동 설치 스크립트
# =============================================================================
set -e

INSTALL_DIR="$HOME/.ssafy-tools"
REPO_URL="https://github.com/junDevCodes/SSAFY_sh_func.git"

echo ""
echo "🚀 SSAFY Shell Functions 설치를 시작합니다..."
echo ""

# 1. 기존 설치 확인
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  기존 설치가 감지되었습니다: $INSTALL_DIR"
    read -r -p "   기존 설치를 삭제하고 다시 설치할까요? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        echo "   ✅ 기존 설치 삭제 완료"
    else
        echo "   ❌ 설치가 취소되었습니다."
        exit 1
    fi
fi

# 2. Git Clone
echo "📥 저장소 다운로드 중..."
if command -v git > /dev/null 2>&1; then
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
else
    echo "❌ Git이 설치되어 있지 않습니다. Git을 먼저 설치해주세요."
    exit 1
fi

# 3. 기존 설치 정리 (중복 방지)
cleanup_old_install() {
    local rc_file="$1"
    if [ -f "$rc_file" ]; then
        # [V7.5] 안전한 정리를 위해 특정 패턴만 제거
        # 타겟 패턴 1: ssafy-tools/algo_functions.sh (표준 설치)
        # 타겟 패턴 2: SSAFY_sh_func/algo_functions.sh (수동 설치)
        
        local tmp_file="${rc_file}.tmp"
        
        # sed를 사용하여 특정 패턴이 포함된 줄만 삭제 (/d)
        # 백업 생성 없이 즉시 처리하면 위험하므로 tmp 파일 사용
        
        # Windows/Linux 호환 sed 처리
        if sed --version >/dev/null 2>&1; then
            # GNU sed
            sed '/ssafy-tools\/algo_functions\.sh/d' "$rc_file" | \
            sed '/SSAFY_sh_func\/algo_functions\.sh/d' > "$tmp_file"
        else
            # BSD sed (macOS)
            sed '/ssafy-tools\/algo_functions\.sh/d' "$rc_file" | \
            sed '/SSAFY_sh_func\/algo_functions\.sh/d' > "$tmp_file"
        fi
        
        mv "$tmp_file" "$rc_file"
    fi
}

add_source_line() {
    local rc_file="$1"
    local source_line="source \"$INSTALL_DIR/algo_functions.sh\""
    
    # 파일이 없으면 생성
    if [ ! -f "$rc_file" ]; then
        touch "$rc_file"
        echo "   ✨ 새 설정 파일 생성: $rc_file"
    fi

    # 기존 다른 경로 정리
    cleanup_old_install "$rc_file"
    
    # 이미 추가되어 있는지 확인
    if grep -q "ssafy-tools/algo_functions.sh" "$rc_file"; then
        echo "   ⏭️  $rc_file 에 이미 설정되어 있습니다."
    else
        # 파일이 비어있지 않으면 개행 추가
        if [ -s "$rc_file" ]; then
            echo "" >> "$rc_file"
        fi
        
        echo "# SSAFY Shell Functions" >> "$rc_file"
        echo "$source_line" >> "$rc_file"
        echo "   ✅ $rc_file 에 설정 추가 완료"
    fi
}

echo ""
echo "🔧 셸 설정 파일 업데이트 중..."

# Bash
add_source_line "$HOME/.bashrc"

# Bash Profile (Windows Git Bash 등 Login Shell 호환)
# .bash_profile이 없으면 생성하고, .bashrc를 로드하도록 설정 (Standard Practice)
if [ ! -f "$HOME/.bash_profile" ] && [ ! -f "$HOME/.profile" ]; then
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "   ✨ Windows Git Bash 환경 감지: .bash_profile 생성"
        echo "if [ -f ~/.bashrc ]; then . ~/.bashrc; fi" > "$HOME/.bash_profile"
        add_source_line "$HOME/.bash_profile"
    fi
elif [ -f "$HOME/.bash_profile" ]; then
    add_source_line "$HOME/.bash_profile"
elif [ -f "$HOME/.profile" ]; then
    add_source_line "$HOME/.profile"
fi

# Zsh (있으면)
if [ -f "$HOME/.zshrc" ]; then
    add_source_line "$HOME/.zshrc"
fi

# 4. 기존 설정 초기화 여부 확인
RUN_SETUP=false
if [ -f "$HOME/.algo_config" ]; then
    echo ""
    echo "⚠️  기존 사용자 설정이 감지되었습니다: ~/.algo_config"
    read -r -p "   기존 설정을 초기화할까요? (새 PC 사용 시 권장) (y/N): " reset_config
    if [[ "$reset_config" =~ ^[Yy]$ ]]; then
        rm "$HOME/.algo_config"
        echo "   ✅ 설정 초기화 완료"
        RUN_SETUP=true
    else
        echo "   ⏭️  기존 설정 유지"
    fi
else
    # 새 설치인 경우도 설정 시작
    RUN_SETUP=true
fi

# 4. 완료 메시지
echo ""
echo "============================================================"
echo "✅ 설치가 완료되었습니다!"
echo "============================================================"
echo ""
echo "👉 지금 바로 사용하려면 아래 명령어를 실행하세요:"
echo ""
echo "   source ~/.bashrc"
echo ""
echo "💡 주요 명령어:"
echo "   - gitup <URL>          : Git 저장소 클론 및 파일 열기"
echo "   - gitdown              : 커밋 후 푸시"
echo "   - algo-config show     : 설정 보기"
echo "   - algo-config edit     : 설정 편집"
echo "   - algo-update          : 최신 버전으로 업데이트"
echo ""
echo "📖 자세한 사용법: https://github.com/junDevCodes/SSAFY_sh_func"
echo ""

# 5. 설정 초기화 시 바로 설정 시작
if [ "$RUN_SETUP" = true ]; then
    echo "🔧 초기 설정을 시작합니다..."
    echo ""
    
    # 설정 파일 생성
    CONFIG_FILE="$HOME/.algo_config"
    cat > "$CONFIG_FILE" << 'EOF'
# 알고리즘 문제 풀이 디렉토리 설정
ALGO_BASE_DIR="$HOME/Desktop/Algorithm-Practics"

# Git 설정
GIT_DEFAULT_BRANCH="main"
GIT_COMMIT_PREFIX="solve"
GIT_AUTO_PUSH=true

# IDE 우선순위 (공백으로 구분)
IDE_PRIORITY="code pycharm idea subl"

# SSAFY 설정
SSAFY_BASE_URL="https://lab.ssafy.com"
SSAFY_USER_ID=""
# [Security V7.7] 토큰은 파일에 저장하지 않음 (세션 전용)
EOF
    
    # SSAFY GitLab 사용자명 입력
    read -r -p "SSAFY GitLab 사용자명 (lab.ssafy.com/{여기} 부분): " ssafy_user
    if [ -n "$ssafy_user" ]; then
        sed -i "s/SSAFY_USER_ID=\"\"/SSAFY_USER_ID=\"$ssafy_user\"/" "$CONFIG_FILE"
    fi
    
    echo ""
    echo "✅ 초기 설정 완료!"
    echo "💡 토큰은 gitup 실행 시 자동으로 안내됩니다."
    echo ""
    read -r -p "🎉 Enter를 누르면 설정을 적용합니다..." _
    exec bash
fi
