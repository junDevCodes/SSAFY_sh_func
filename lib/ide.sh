# =============================================================================
# lib/ide.sh
# IDE Configuration & Management
# =============================================================================

# 에디터에서 파일 열기 내부 함수
_open_in_editor() {
    local editor="$1"
    local file="$2"
    
    case "$editor" in
        pycharm*|idea*)
            if command -v "$editor" > /dev/null 2>&1; then
                "$editor" "$file" &
            else
                echo "⚠️  $editor를 찾을 수 없습니다"
                code "$file" 2>/dev/null || echo "❌ 파일 열기 실패"
            fi
            ;;
        *)
            if command -v "$editor" > /dev/null 2>&1; then
                "$editor" "$file" &
            else
                echo "⚠️  $editor를 찾을 수 없습니다"
            fi
            ;;
    esac
}

# ===================================================
# get_ide - 설정된 IDE 반환
# ===================================================
get_ide() {
    # Ensure config is loaded
    if type init_algo_config >/dev/null 2>&1; then
        init_algo_config
    fi
    
    # IDE_EDITOR가 설정되어 있으면 사용
    if [ -n "${IDE_EDITOR:-}" ]; then
        echo "$IDE_EDITOR"
        return
    fi
    
    # 하위 호환: IDE_PRIORITY가 있으면 첫 번째 값 사용
    if [ -n "${IDE_PRIORITY:-}" ]; then
        local first_ide
        first_ide=$(echo "$IDE_PRIORITY" | awk '{print $1}')
        echo "$first_ide"
        return
    fi
    
    # 기본값
    echo "code"
}

# 하위 호환성을 위한 별칭
get_active_ide() {
    get_ide
}

# =============================================================================
# check_ide - IDE 디버깅 정보
# =============================================================================
check_ide() {
    if type init_algo_config >/dev/null 2>&1; then
        init_algo_config
    fi
    
    echo "🔍 IDE 감지 디버깅 정보:"
    echo ""
    echo "💻 운영체제: $OSTYPE"
    echo "📁 현재 위치: $(pwd)"
    echo ""
    
    # 운영체제 감지
    local os_type=""
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || command -v powershell.exe > /dev/null 2>&1; then
        os_type="windows"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os_type="mac"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os_type="linux"
    fi
    
    echo "1️⃣ 실행 중인 IDE 프로세스:"
    case "$os_type" in
        "windows")
            # Windows: tasklist 또는 PowerShell 사용
            if command -v tasklist > /dev/null 2>&1; then
                local ide_processes=$(tasklist 2>/dev/null | grep -iE "(code|pycharm|idea|subl)" || echo "")
                if [ -n "$ide_processes" ]; then
                    echo "$ide_processes" | head -10
                else
                    echo "   ❌ IDE 프로세스를 찾을 수 없습니다"
                fi
            elif command -v powershell.exe > /dev/null 2>&1; then
                local ide_processes=$(powershell.exe -Command "Get-Process | Where-Object {\$_.ProcessName -like '*code*' -or \$_.ProcessName -like '*pycharm*' -or \$_.ProcessName -like '*idea*' -or \$_.ProcessName -like '*subl*'} | Select-Object ProcessName,Id" 2>/dev/null)
                if [ -n "$ide_processes" ]; then
                    echo "$ide_processes"
                else
                    echo "   ❌ IDE 프로세스를 찾을 수 없습니다"
                fi
            else
                echo "   ⚠️  프로세스 확인 도구를 찾을 수 없습니다"
            fi
            ;;
        "mac"|"linux")
            # macOS/Linux: ps 또는 pgrep 사용
            if command -v pgrep > /dev/null 2>&1; then
                local ide_found=false
                for ide in code pycharm idea subl; do
                    if pgrep -f "$ide" > /dev/null 2>&1; then
                        echo "   ✅ $ide 실행 중"
                        ide_found=true
                    fi
                done
                if [ "$ide_found" = false ]; then
                    echo "   ❌ IDE 프로세스를 찾을 수 없습니다"
                fi
            elif command -v ps > /dev/null 2>&1; then
                local ide_processes=$(ps aux 2>/dev/null | grep -E "(pycharm|idea|code|subl)" | grep -v grep || echo "")
                if [ -n "$ide_processes" ]; then
                    echo "$ide_processes" | head -10
                else
                    echo "   ❌ IDE 프로세스를 찾을 수 없습니다"
                fi
            else
                echo "   ⚠️  프로세스 확인 도구를 찾을 수 없습니다"
            fi
            ;;
        *)
            echo "   ⚠️  알 수 없는 운영체제"
            ;;
    esac
    
    echo ""
    echo "2️⃣ get_active_ide() 결과:"
    local detected_ide=$(get_active_ide)
    echo "   감지된 IDE: '$detected_ide'"
    
    echo ""
    echo "3️⃣ IDE 명령어 확인:"
    # Phase 5 Task 5-4: IDE 리스트 로직 명확화
    local ide_list
    if [ -n "${IDE_EDITOR:-}" ]; then
        # IDE_EDITOR가 설정되어 있으면 해당 IDE만 검사
        ide_list="$IDE_EDITOR"
    elif [ -n "${IDE_PRIORITY:-}" ]; then
        # IDE_PRIORITY가 설정되어 있으면 전체 리스트 검사
        ide_list="$IDE_PRIORITY"
    else
        # 기본값: 주요 IDE 전체 검사
        ide_list="code pycharm idea subl cursor antigravity"
    fi
    
    for ide in $ide_list; do
        local ide_cmd="$ide"
        case "$ide" in
            pycharm)
                if [ "$os_type" = "windows" ]; then
                    ide_cmd="pycharm64.exe"
                elif [ "$os_type" = "linux" ]; then
                    ide_cmd="pycharm.sh"
                fi
                ;;
            idea)
                if [ "$os_type" = "windows" ]; then
                    ide_cmd="idea64.exe"
                elif [ "$os_type" = "linux" ]; then
                    ide_cmd="idea.sh"
                fi
                ;;
        esac
        
        if command -v "$ide_cmd" >/dev/null 2>&1; then
            echo "   ✅ $ide ($ide_cmd) - 설치됨"
        else
            echo "   ❌ $ide ($ide_cmd) - 설치되지 않음"
        fi
    done
    
    echo ""
    echo "4️⃣ 현재 설정:"
    # Phase 2 Task 2-2: IDE_EDITOR와 IDE_PRIORITY 모두 검색
    algo_config show | grep -E "IDE_EDITOR|IDE_PRIORITY" || echo "   설정 파일을 찾을 수 없습니다"
    
    echo ""
    echo "💡 IDE 우선순위를 변경하려면: algo-config edit"
}

# =============================================================================
# _setup_ide_aliases - IDE 자동 탐색 및 별칭 설정 (V7.3)
# =============================================================================
_setup_ide_aliases() {
    [ -z "${IDE_EDITOR:-}" ] && return 0
    
    # 이미 명령어가 존재하면 패스
    if command -v "$IDE_EDITOR" >/dev/null 2>&1; then
        return 0
    fi
    
    local cache_file="$HOME/.ssafy_ide_cache"
    
    # 캐시 확인
    if [ -f "$cache_file" ]; then
        source "$cache_file"
        # 로드 후 다시 확인
        if command -v "$IDE_EDITOR" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    # 자동 탐색 시작
    local target_exe=""
    case "$IDE_EDITOR" in
        pycharm) target_exe="pycharm64.exe" ;;
        idea)    target_exe="idea64.exe" ;;
        subl)    target_exe="subl.exe" ;;
        cursor)  target_exe="Cursor.exe" ;;
        antigravity) target_exe="Antigravity.exe" ;;
        *)       return 0 ;; # 모르는 IDE는 탐색 안 함
    esac
    
    # echo "🔎 $IDE_EDITOR 명령어를 찾을 수 없어 설치 경로를 검색합니다..."
    
    local found_path=""
    local search_paths=(
        "/c/Program Files"
        "/c/Program Files (x86)"
        "$HOME/AppData/Local/JetBrains"
        "$HOME/AppData/Local/Programs"
        "$HOME/AppData/Local"
    )
    
    for base_path in "${search_paths[@]}"; do
        [ ! -d "$base_path" ] && continue
        
        # 3단계 깊이까지만 빠르게 검색 (속도 최적화)
        found_path=$(find "$base_path" -maxdepth 5 -name "$target_exe" -print -quit 2>/dev/null)
        
        if [ -n "$found_path" ]; then
            break
        fi
    done
    
    if [ -n "$found_path" ]; then
        # 경로에 공백이 있을 수 있으므로 따옴표 처리
        local alias_cmd="alias $IDE_EDITOR=\"'$found_path'\""
        
        # 현재 세션 적용
        alias "$IDE_EDITOR"="'$found_path'"
        
        # 캐시 저장
        echo "$alias_cmd" >> "$cache_file"
        # echo "✅ IDE 연결 완료: $found_path"
    fi
}
