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

# 3. 셸 설정 파일에 source 문 추가
add_source_line() {
    local rc_file="$1"
    local source_line="source \"$INSTALL_DIR/algo_functions.sh\""
    
    if [ -f "$rc_file" ]; then
        # 이미 추가되어 있는지 확인
        if grep -q "ssafy-tools/algo_functions.sh" "$rc_file"; then
            echo "   ⏭️  $rc_file 에 이미 설정되어 있습니다."
        else
            echo "" >> "$rc_file"
            echo "# SSAFY Shell Functions" >> "$rc_file"
            echo "$source_line" >> "$rc_file"
            echo "   ✅ $rc_file 에 설정 추가 완료"
        fi
    fi
}

echo ""
echo "🔧 셸 설정 파일 업데이트 중..."

# Bash
add_source_line "$HOME/.bashrc"

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
    source "$INSTALL_DIR/algo_functions.sh"
fi
