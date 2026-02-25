# =============================================================================
# lib/help.sh
# 통합 도움말
# =============================================================================

_ssafy_algo_help_print_links() {
    echo "  - gitup/gitdown 상세 가이드: https://jundevcodes.github.io/SSAFY_sh_func/guide.html"
    echo "  - al(algorithm) 상세 가이드: https://jundevcodes.github.io/SSAFY_sh_func/alias.html"
}

_ssafy_algo_help_print_summary() {
    if type ui_panel_begin > /dev/null 2>&1; then
        ui_panel_begin "algo-help" "주요 명령어 요약"
        ui_section "파일 생성"
        ui_info "al <site> <번호> [py|cpp] [옵션]"
        ui_info "  예시: al b 1000 py"
        ui_info "  예시: al b 1000 py --no-git --no-open"
        ui_section "저장소 clone"
        ui_info "gitup <URL | SSAFY-토픽 | SmartLink>"
        ui_info "  예시: gitup https://github.com/user/repo.git"
        ui_info "  예시: gitup data_ws_4   (SSAFY 세션 토픽)"
        ui_section "커밋/푸시"
        ui_info "gitdown             (SSAFY 세션 루트: 전체 배치 / 개별 레포: 단일)"
        ui_info "gitdown --all, -a   (강제 전체 배치)"
        ui_info "gitdown -m \"메시지\" (메시지 직접 지정)"
        ui_section "설정"
        ui_info "algo-config show    (현재 설정 확인)"
        ui_info "algo-config edit    (설정 변경 - GUI 마법사)"
        ui_info "algo-config reset   (설정 초기화)"
        ui_section "기타"
        ui_info "algo-update         (최신 버전으로 업데이트)"
        ui_info "algo-doctor         (환경 진단)"
        ui_section "상세 도움말"
        ui_info "algo-help <명령어>  예시: algo-help gitdown"
        ui_section "참고 링크"
        ui_info "gitup/gitdown: https://jundevcodes.github.io/SSAFY_sh_func/guide.html"
        ui_info "al: https://jundevcodes.github.io/SSAFY_sh_func/alias.html"
        ui_panel_end
        return 0
    fi

    echo "=============================="
    echo " SSAFY Algo Tools 주요 명령어"
    echo "=============================="
    echo ""
    echo "[파일 생성]"
    echo "  al <site> <번호> [py|cpp] [옵션]"
    echo "  예시: al b 1000 py"
    echo "  예시: al b 1000 py --no-git --no-open"
    echo ""
    echo "[저장소 clone]"
    echo "  gitup <URL | SSAFY-토픽 | SmartLink>"
    echo "  예시: gitup https://github.com/user/repo.git"
    echo "  예시: gitup data_ws_4   (SSAFY 세션 토픽)"
    echo ""
    echo "[커밋/푸시]"
    echo "  gitdown             (SSAFY 세션 루트: 전체 배치 / 개별 레포: 단일)"
    echo "  gitdown --all, -a   (강제 전체 배치)"
    echo "  gitdown -m \"msg\"    (메시지 직접 지정)"
    echo ""
    echo "[설정]"
    echo "  algo-config show    (현재 설정 확인)"
    echo "  algo-config edit    (설정 변경 - GUI 마법사)"
    echo "  algo-config reset   (설정 초기화)"
    echo ""
    echo "[기타]"
    echo "  algo-update         (최신 버전으로 업데이트)"
    echo "  algo-doctor         (환경 진단)"
    echo ""
    echo "[상세 도움말]"
    echo "  algo-help <명령어>  예시: algo-help gitdown"
    echo ""
    _ssafy_algo_help_print_links
}

_ssafy_algo_help_print_command() {
    local cmd="$1"
    case "$cmd" in
        al)
            if type ui_panel_begin > /dev/null 2>&1; then
                ui_panel_begin "algo-help" "al - 알고리즘 파일 생성"
                ui_section "사용법"
                ui_info "al <site> <번호> [py|cpp] [옵션]"
                ui_section "인자"
                ui_info "site   : b(baekjoon), p(programmers), s(swea), l(leetcode)"
                ui_info "번호   : 문제 번호 (숫자)"
                ui_info "py|cpp : 언어 선택 (기본: py)"
                ui_section "옵션"
                ui_info "--no-git   : git add/commit 건너뜀"
                ui_info "--no-open  : IDE에서 파일 열기 건너뜀"
                ui_section "예시"
                ui_info "al b 1000 py"
                ui_info "al b 1000 cpp"
                ui_info "al p 42 py --no-git"
                ui_section "참고"
                ui_info "https://jundevcodes.github.io/SSAFY_sh_func/alias.html"
                ui_panel_end
            else
                echo "[al 도움말]"
                echo "  사용법: al <site> <번호> [py|cpp] [옵션]"
                echo "  site : b(baekjoon), p(programmers), s(swea), l(leetcode)"
                echo "  옵션 : --no-git, --no-open"
                echo "  예시 : al b 1000 py"
                echo "  예시 : al b 1000 cpp --no-open"
                echo "  상세 : https://jundevcodes.github.io/SSAFY_sh_func/alias.html"
            fi
            ;;
        gitup)
            if type ui_panel_begin > /dev/null 2>&1; then
                ui_panel_begin "algo-help" "gitup - 저장소 clone"
                ui_section "사용법"
                ui_info "gitup [URL | SSAFY-토픽 | SmartLink]"
                ui_info "인자 없이 실행하면 대화형 입력 모드 시작"
                ui_section "입력 모드"
                ui_info "1. SmartLink : URL|Bearer토큰 형식 한 번에 붙여넣기"
                ui_info "2. URL       : Git 저장소 URL 직접 입력"
                ui_info "3. Topic     : SSAFY 토픽 형식 (예: data_ws_3)"
                ui_section "예시"
                ui_info "gitup https://github.com/user/repo.git"
                ui_info "gitup data_ws_4"
                ui_info "gitup --ssafy data_ws_4"
                ui_info "gitup  (← 대화형 모드)"
                ui_section "SSAFY 토픽 형식"
                ui_info "<주제>_ws_<세션>  또는  <주제>_hw_<세션>"
                ui_info "예시: algo_ws_3, data_hw_5"
                ui_section "참고"
                ui_info "https://jundevcodes.github.io/SSAFY_sh_func/guide.html"
                ui_panel_end
            else
                echo "[gitup 도움말]"
                echo "  사용법: gitup [URL | SSAFY-토픽 | SmartLink]"
                echo "  인자 없이 실행 시 대화형 모드"
                echo "  예시: gitup https://github.com/user/repo.git"
                echo "  예시: gitup data_ws_4"
                echo "  상세: https://jundevcodes.github.io/SSAFY_sh_func/guide.html"
            fi
            ;;
        gitdown)
            if type ui_panel_begin > /dev/null 2>&1; then
                ui_panel_begin "algo-help" "gitdown - 커밋 & 푸시"
                ui_section "기본 동작"
                ui_info "SSAFY 세션 루트에서 실행  →  전체 폴더 일괄 커밋/푸시"
                ui_info "개별 레포 안에서 실행     →  현재 폴더만 커밋/푸시"
                ui_section "옵션"
                ui_info "--all, -a       : 강제 전체 배치 (세션 루트 기준)"
                ui_info "--msg, -m \"msg\" : 커밋 메시지 직접 지정"
                ui_info "--ssafy, -s     : SSAFY 모드 강제 활성화"
                ui_section "예시"
                ui_info "gitdown             (자동 감지)"
                ui_info "gitdown -a          (전체 배치 강제)"
                ui_info "gitdown -m \"fix: 수정\"  (메시지 지정)"
                ui_info "gitdown -a -m \"solve: 일괄\"  (배치 + 메시지)"
                ui_section "SSAFY 세션 루트 감지"
                ui_info ".ssafy_session_root, .ssafy_playlist,"
                ui_info ".ssafy_session_meta 파일이 있으면 세션 루트로 인식"
                ui_section "참고"
                ui_info "https://jundevcodes.github.io/SSAFY_sh_func/guide.html"
                ui_panel_end
            else
                echo "[gitdown 도움말]"
                echo "  기본 동작: SSAFY 세션 루트 → 전체 배치 / 개별 레포 → 단일 커밋"
                echo "  옵션:"
                echo "    --all, -a       : 강제 전체 배치"
                echo "    --msg, -m \"msg\" : 커밋 메시지 직접 지정"
                echo "  예시: gitdown"
                echo "  예시: gitdown -a"
                echo "  예시: gitdown -m \"fix: 수정\""
                echo "  상세: https://jundevcodes.github.io/SSAFY_sh_func/guide.html"
            fi
            ;;
        algo-config|config)
            if type ui_panel_begin > /dev/null 2>&1; then
                ui_panel_begin "algo-help" "algo-config - 설정 관리"
                ui_section "서브커맨드"
                ui_info "algo-config show   : 현재 설정 값 확인"
                ui_info "algo-config edit   : GUI 마법사로 설정 변경"
                ui_info "algo-config reset  : 모든 설정 초기화"
                ui_section "주요 설정 항목"
                ui_info "ALGO_BASE_DIR      : 알고리즘 파일 저장 경로"
                ui_info "IDE_EDITOR         : 사용 IDE (code, cursor, pycharm...)"
                ui_info "GIT_DEFAULT_BRANCH : 기본 push 브랜치"
                ui_info "GIT_COMMIT_PREFIX  : 커밋 메시지 접두사 (기본: solve)"
                ui_info "GIT_AUTO_PUSH      : 커밋 후 자동 push 여부"
                ui_info "SSAFY_USER_ID      : lab.ssafy.com 사용자 ID"
                ui_panel_end
            else
                echo "[algo-config 도움말]"
                echo "  algo-config show   : 설정 확인"
                echo "  algo-config edit   : 설정 변경 (GUI 마법사)"
                echo "  algo-config reset  : 초기화"
            fi
            ;;
        algo-update|update)
            if type ui_panel_begin > /dev/null 2>&1; then
                ui_panel_begin "algo-help" "algo-update - 업데이트"
                ui_section "사용법"
                ui_info "algo-update"
                ui_section "설명"
                ui_info "설치된 SSAFY Algo Tools를 최신 버전으로 업데이트합니다."
                ui_info "업데이트 채널: SSAFY_UPDATE_CHANNEL 설정에 따름"
                ui_info "  stable (기본): 안정 릴리즈"
                ui_info "  edge: 최신 main 브랜치"
                ui_panel_end
            else
                echo "[algo-update 도움말]"
                echo "  사용법: algo-update"
                echo "  최신 버전으로 업데이트합니다."
            fi
            ;;
        algo-doctor|doctor)
            if type ui_panel_begin > /dev/null 2>&1; then
                ui_panel_begin "algo-help" "algo-doctor - 환경 진단"
                ui_section "사용법"
                ui_info "algo-doctor"
                ui_section "설명"
                ui_info "설치 환경, 설정, 의존 도구(git, python, IDE)를"
                ui_info "진단하고 문제 발생 시 수정 안내를 제공합니다."
                ui_panel_end
            else
                echo "[algo-doctor 도움말]"
                echo "  사용법: algo-doctor"
                echo "  환경 및 설정 진단을 수행합니다."
            fi
            ;;
        *)
            if type ui_warn > /dev/null 2>&1; then
                ui_warn "지원하지 않는 명령어: $cmd"
                ui_info "사용 가능: al, gitup, gitdown, algo-config, algo-update, algo-doctor"
            else
                echo "[WARN] 지원하지 않는 명령어입니다: $cmd"
                echo "전체 목록은 'algo-help'를 실행하세요."
            fi
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
