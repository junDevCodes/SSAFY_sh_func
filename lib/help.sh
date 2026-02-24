# =============================================================================
# lib/help.sh
# 통합 도움말
# =============================================================================

_ssafy_algo_help_print_links() {
    echo "참고 링크"
    echo "  - gitup/gitdown 상세 가이드: https://jundevcodes.github.io/SSAFY_sh_func/guide.html"
    echo "  - al(algorithm) 상세 가이드: https://jundevcodes.github.io/SSAFY_sh_func/alias.html"
}

_ssafy_algo_help_print_summary() {
    if type ui_header >/dev/null 2>&1; then
        ui_header "algo-help" "주요 명령어 요약"
        ui_info "al: 알고리즘 문제 폴더/파일 템플릿 생성"
        ui_info "예시: al b 1000 py --no-git --no-open"
        ui_info "gitup: 저장소 clone + SSAFY 토픽/스마트링크 지원"
        ui_info "예시: gitup https://github.com/user/repo.git"
        ui_info "gitdown: 현재 저장소 커밋/푸시 및 SSAFY 후속 흐름"
        ui_info "예시: gitdown"
        ui_info "algo-config: 설정 조회/수정/초기화"
        ui_info "예시: algo-config show"
        ui_info "algo-update: 최신 버전 업데이트"
        ui_info "예시: algo-update"
        ui_info "algo-doctor: 환경/설정 진단"
        ui_info "예시: algo-doctor"
        ui_section "링크"
        ui_info "gitup/gitdown: https://jundevcodes.github.io/SSAFY_sh_func/guide.html"
        ui_info "al: https://jundevcodes.github.io/SSAFY_sh_func/alias.html"
        return 0
    fi

    echo "주요 명령어 요약"
    echo "  - al: 알고리즘 문제 폴더/파일 템플릿 생성"
    echo "    예시: al b 1000 py --no-git --no-open"
    echo "  - gitup: 저장소 clone + SSAFY 토픽/스마트링크 지원"
    echo "    예시: gitup https://github.com/user/repo.git"
    echo "  - gitdown: 현재 저장소 커밋/푸시 및 SSAFY 후속 흐름"
    echo "    예시: gitdown"
    echo "  - algo-config: 설정 조회/수정/초기화"
    echo "    예시: algo-config show"
    echo "  - algo-update: 최신 버전 업데이트"
    echo "    예시: algo-update"
    echo "  - algo-doctor: 환경/설정 진단"
    echo "    예시: algo-doctor"
    _ssafy_algo_help_print_links
}

_ssafy_algo_help_print_command() {
    local cmd="$1"
    case "$cmd" in
        al)
            echo "al 도움말"
            echo "  - 사용 예시: al <site> <problem> [py|cpp] [options]"
            echo "  - 상세 문서: https://jundevcodes.github.io/SSAFY_sh_func/alias.html"
            ;;
        gitup)
            echo "gitup 도움말"
            echo "  - 사용 예시: gitup <git-url | ssafy-topic | smart-link>"
            echo "  - 상세 문서: https://jundevcodes.github.io/SSAFY_sh_func/guide.html"
            ;;
        gitdown)
            echo "gitdown 도움말"
            echo "  - 사용 예시: gitdown | gitdown --all"
            echo "  - 상세 문서: https://jundevcodes.github.io/SSAFY_sh_func/guide.html"
            ;;
        algo-config)
            echo "algo-config 도움말"
            echo "  - 사용 예시: algo-config show | algo-config edit | algo-config reset"
            ;;
        algo-update)
            echo "algo-update 도움말"
            echo "  - 사용 예시: algo-update"
            ;;
        algo-doctor)
            echo "algo-doctor 도움말"
            echo "  - 사용 예시: algo-doctor"
            ;;
        *)
            echo "지원하지 않는 명령어입니다: $cmd"
            echo "전체 목록은 'algo-help'를 실행하세요."
            return 1
            ;;
    esac
}

ssafy_algo_help() {
    local target="${1:-}"
    if [ -z "$target" ]; then
        _ssafy_algo_help_print_summary
        return 0
    fi
    _ssafy_algo_help_print_command "$target"
}
