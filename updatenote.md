# 📋 업데이트 노트 (Release Notes)

## V8.1.2 (2026-01-28) - Submission Link Fix & UX Improvements 🧩

### 🔗 제출 링크 안정화 (Submission Link)
- **제출 URL 경로 수정**: `practiceroom` 경로로 제출 링크 생성하도록 수정
- **course_id 디코딩 보강**: `.ssafy_session_meta`의 `course_id`(base64) 디코딩 및 CRLF/공백 제거 처리
- **PR/PA 디코딩 공통화**: base64 디코딩 로직을 공통 함수로 통일하여 OS 호환성 강화

### 🧭 gitup UX 개선 (IDE/File Open)
- **VS Code/Cursor 파일 오픈 규칙 개선**:
  - 파일 1개면 바로 열기
  - 파일 5개 이하면 목록 출력 + 번호 선택으로 열기
  - 파일 5개 초과면 `skeleton/` 우선 포함한 상위 5개 목록 + 번호 선택
- **폴더 오픈 방지**: 파일이 없을 때는 워크스페이스 오염을 막기 위해 폴더를 열지 않도록 변경

### ✅ 진행상태 관리 개선 (Progress)
- `.ssafy_progress`를 **append가 아닌 update 방식**으로 갱신하여 중복 항목 누적 방지

### 🔐 보안/지속성 (Security & Persistence)
- **토큰 저장 가드**: `SSAFY_AUTH_TOKEN`은 설정 파일에 저장하지 않고 세션에서만 유지하도록 차단
- **status 캐시 위치 변경**: `/tmp` → `$HOME/.algo_status_cache`로 변경하여 재부팅 후에도 캐시 유지

---

## V8.1.1 (2026-01-27) - Code Quality & Bug Fix 🔧

### 🐛 버그 수정 (Critical Bug Fix)
- **IDE 열기 로직 수정**: `_open_in_editor` 함수 호출 시 인자 누락으로 파일이 열리지 않던 문제 수정
- **설정 파일 경로 통일**: `~/.algo_config`로 경로 일원화 (기존 `.ssafy_algo_config` 혼용 문제 해결)
- **Python 메뉴 번호 중복**: `algo_config_wizard.py`의 4번 메뉴 중복 표시 문제 수정
- **import 중복 제거**: `ssafy_batch_create.py`의 `import os` 중복 제거

### ⚡ 성능 개선 (Performance)
- **파일 탐색 최적화**: `_open_repo_file` 함수에서 중복 `find` 명령어 제거
- **서비스 상태 캐싱**: `_check_service_status`에 24시간 캐싱 적용 (터미널 로딩 속도 개선)

### 🏗️ 아키텍처 개선 (Architecture)
- **ALGO_ROOT_DIR 전역 변수 도입**: 모든 모듈에서 일관된 경로 참조 가능
- **sed 공통 함수 추출**: `_sed_inplace()` 함수로 macOS/Linux 호환성 확보
- **IDE 변수 통일**: `IDE_EDITOR` 사용 권장, `IDE_PRIORITY` 하위 호환성 유지

### 📝 코드 품질 (Code Quality)
- **변수 스코프 수정**: `_check_service_status`의 `json` 변수 전역 오염 방지
- **IDE 열기 로직 개선**: 비-VSCode IDE에서 중복 창 열림 문제 수정
- **모듈 구조 문서화**: `algo_functions.sh`에 모듈별 역할 주석 추가

### 📊 통계
- 28개 이슈 중 27개 수정 완료 (96.4%)
- 잔여 이슈: H-01 (배포용 단일 파일 빌드 - 미래 과제)

---


## V8.1.0 (2026-01-26) - Modular Architecture & Kill Switch 🛡️

### 🏗️ 모듈화 리팩토링 (Modular Refactoring)
- **Codebase Modularization**: 거대한 `algo_functions.sh` 단일 파일을 `lib/` 디렉토리 하위의 기능별 모듈(`config.sh`, `utils.sh`, `auth.sh`, `git.sh`, `ide.sh`, `doctor.sh` 등)로 분리했습니다.
  - 유지보수성과 확장성이 대폭 향상되었습니다.
  - 사용자는 기존과 동일하게 `source algo_functions.sh`만 하면 내부적으로 필요한 모듈을 로드합니다.

### 🚦 킬 스위치 (Kill Switch) 도입
- **원격 제어 시스템**: 치명적인 버그나 보안 이슈 발생 시, 원격의 `status.json`을 통해 도구 사용을 제한하거나 경고 메시지를 보낼 수 있습니다.
  - **Active**: 정상 작동
  - **Maintenance**: 경고 메시지 출력 후 정상 작동
  - **Outage**: 사용 차단 (긴급 점검)
- **Fail-Open 정책**: 네트워크 문제 등으로 상태 확인 실패 시, 사용자 경험을 위해 **정상(Active)** 상태로 간주하여 실행을 차단하지 않습니다.

### 🔐 보안 및 안정성 강화
- **Session-Only Token**: V7.7의 보안 정책을 더욱 강화하여, 토큰 처리 로직을 완전히 세션 메모리 기반으로 재검증했습니다.
- **Fail-Safe**: `curl` 타임아웃, JSON 파싱 오류 등에 대한 방어 로직을 추가하여 네트워크 불안정 상황에서도 스크립트가 멈추지 않습니다.

---

## V8.0.0 (2026-01-26) - Lazy Runtime Resolution Architecture 🏗️

### 🔄 아키텍처 변경 (Major Architectural Change)
- **지연된 런타임 확정 (Lazy Runtime Resolution)**: V7.8의 "설치 시점 고정" 방식이 환경 변화에 취약하다는 피드백을 수용하여, **필요한 순간에 최적의 도구를 찾는 방식**으로 설계를 완전히 변경했습니다.
  - 쉘 시작 시점(`source`)에는 아무런 탐색도 하지 않습니다. (부하 0)
  - `gitup` 등 실제 Python이 필요한 명령을 실행할 때 시스템을 탐색하여 `python3` -> `python`(Shim 제외) -> `py` 순으로 유효한 인터프리터를 찾습니다.
  - 한 번 찾은 경로는 세션 동안 캐싱되어 성능 저하가 없습니다.
- **설치 스크립트 복구**: `install.sh`가 더 이상 사용자의 `~/.bashrc`에 환경변수나 별칭을 강제 주입하지 않습니다. (Clean Install)

## V7.8.0 (2026-01-26) - Permanent Python Path Binding 🔗

### ✨ 근본적인 해결 (Fundamental Solution)
- **설치 시점 Python 고정**: 더 이상 매번 실행할 때마다 Python을 찾아 헤매지 않습니다.
  - `install.sh` 실행 시 시스템에서 가장 적합한 Python(`python3`, `py`, `python`)을 찾아, 사용자의 쉘 프로필(`~/.bashrc`)에 **영구적으로 등록**합니다.
  - 등록된 별칭(`alias python=...`)을 통해, 터미널에서 `python` 입력 시 무조건 올바른 인터프리터가 실행되도록 보장합니다.
  - **효과**: Windows Store Shim(가짜 파이썬) 문제 원천 차단 및 실행 속도 소폭 향상


### 🐛 실행 오류 최종 수정 (Final Fix)
- **`py` 런처 지원**: `python`이나 `python3` 명령어가 없어도, Windows에 기본 설치되는 **Python Launcher (`py`)**를 감지하여 실행하도록 개선했습니다.
  - V7.5에서 정상 동작했던 원인이 바로 이 `py` 런처였을 가능성이 높으며, 이번 패치로 완벽하게 호환됩니다.
- **명시적 에러 메시지**: 만약 시스템에서 유효한 Python을 전혀 찾을 수 없는 경우, 알 수 없는 오류 대신 **"Python을 찾을 수 없습니다"**라는 명확한 원인을 출력하고 실행을 중단합니다.



### 🐛 버그 수정 (Critial Bug Fix)
- **Python Windows Store Shim 감지 우회**: `python` 명령어가 존재하더라도 실행 시 Microsoft Store로 연결되는(Shim) 경우를 감지하여, 유효한 Python 인터프리터만 사용하도록 개선했습니다.
  - 이제 `gitup` 실행 시 "Python was not found" 오류가 더 이상 발생하지 않습니다.
- **설치 스크립트 중복 로드 해결**: `install.sh` 실행 시 `.bash_profile`과 `.bashrc`에 중복으로 설정이 추가되어 "알고리즘 셸 함수 로드 완료!" 메시지가 두 번 뜨던 문제를 수정했습니다.
  - `.bash_profile`은 이제 `.bashrc`를 로드하도록만 설정되며, 실제 도구 로딩은 `.bashrc`에서 한 번만 수행됩니다.

## V7.7.2 (2026-01-26) - Hotfix: Critical Install Fix 🚑

### 🐛 설치 스크립트 수정 (Critical Fix)
- **설정 파일 미생성 오류 해결**: V7.7.1에서 보고된 문제로, 사용자의 PC에 `.bashrc`나 `.bash_profile`이 존재하지 않는 경우(초기 환경) 설치 스크립트가 설정을 추가하지 않고 건너뛰던 문제를 수정했습니다.
  - 개선 후: 설정 파일이 없으면 자동으로 생성하고, 특히 Windows Git Bash 환경에서는 `.bash_profile`을 생성하여 로그인 셸 호환성을 보장합니다.


## V7.7.0 (2026-01-25) - Security Hardening 🔐

### 🔐 보안 강화 (Breaking Change)
- **토큰 세션화**: `~/.algo_config`에 토큰을 더 이상 저장하지 않습니다.
  - 토큰은 환경변수(`$SSAFY_AUTH_TOKEN`)로만 유지
  - **터미널 종료 시 자동 삭제** (파일 유출 위험 제거)

### ✨ 변경 사항
- `_ensure_token()`: 세션에 토큰 없을 때 입력 요청하는 새 함수
- `ssafy_batch_create.py`: 파일 저장 함수 제거
- `algo_config_wizard.py`: 토큰 메뉴 → 세션 전용 안내로 변경
- `algo-doctor`: "세션 전용" 상태 표시

---

## V7.5.2 (2026-01-23) - Documentation & Config Enhancement 📖

### ✨ 새로운 기능
- **Git 설정 메뉴 추가**: `algo-config edit`에서 메뉴 5번으로 Git 설정(커밋 접두사, 기본 브랜치, 자동 푸시)을 변경할 수 있습니다.
- **Playlist 완료 링크**: 모든 문제 완료 시 전체 제출 페이지 링크가 출력됩니다.

### 📖 문서 개선
- **헤더 명령어 강조**: `gitup`, `gitdown`, `al` 코드가 헤더에서 더 잘 보이도록 스타일 추가
- **Smart Batch 계층화**: gitup 하위 기능으로 표시되도록 구조 변경
- **gitdown Prefix 설명**: 커밋 접두사에 따라 메시지가 생성됨을 명시
- **파일 트리 구조**: `al` 명령으로 생성되는 폴더 구조 시각화
- **al 재사용 워크플로우**: 같은 문제를 여러 번 실행했을 때 동작 설명

---

## V7.4.5 (2026-01-23) - Masked Input Critical Fix 🚑

### 🐛 버그 수정 (Critial Bug Fix)
- **Masked Input 입력 오류 해결**: V7.4.4에서 도입된 Masked Input 기능 사용 시, 프롬프트 문자열(`👉 Paste Here...`)이 입력값에 함께 포함되어 인증 및 클론 실패를 유발하던 치명적인 오류를 수정했습니다.
  - 이제 프롬프트와 별표(`*`) 출력이 정상적으로 분리되어, 오직 사용자가 입력한 토큰/URL 값만 정확하게 인식됩니다.

---

## V7.4.4 (2026-01-23) - Masked Input Re-implementation 🎭

### ✨ 개선 사항
- **Masked Input 복구 및 개선**: `gitup`의 Secure Input 모드에서 다시 **Asterisk(*)** 입력을 지원합니다.
  - 개선사항: 입력 완료 메시지(`Input Received`)를 제거하여, 별표(`****`)만 확인하고 즉시 다음 단계(토큰 업데이트)로 넘어가도록 출력 방식을 간소화했습니다.

---

## V7.4.3 (2026-01-23) - Hotfix: Revert Masked Input (Rollback) ↩️

### ⚠️ 변경 사항 (Corrections)
- **Secure Input 롤백**: V7.4.2에서 도입한 Asterisk(*) 입력 표시 기능이 일부 환경에서 입력 지연/오류를 유발하여, **기존의 숨김 입력 방식(V7.4.1)**으로 복구했습니다.
- **안정성 유지**: 업데이트 편의성을 위한 `algo-update` 강제 동기화 로직은 그대로 유지됩니다.

---

## V7.4.2 (2026-01-23) - Masked Input Support 🎭

### ✨ 개선 사항
- **Secure Input 시각화**: `gitup`에서 토큰/URL 붙여넣기 시, 기존에는 아무것도 보이지 않았으나 이제 **Asterisk(*)** 문자로 입력된 내용을 시각적으로 확인할 수 있습니다.
- **업데이트 안정성 강화**: `algo-update` 시 강제 동기화(`git reset --hard`) 로직을 추가하여 업데이트 실패율을 최소화했습니다.

---

## V7.4.1 (2026-01-23) - Feedback & UX Improvements 📣

### ✨ 개선 사항 (Improvements)
- **실습실 오픈 과정 가시화**: `gitup` 스마트 배치 모드 실행 시, 백그라운드에서 수행되는 과정(로그인, 생성 등)을 화면에 실시간으로 표시
- **보안 입력 피드백 추가**: Secure Input 모드에서 붙여넣기 시 "입력 수신 완료(글자수)" 메시지 표시로 입력 여부 확인 가능
- **진행 상황 초기화**: `gitup` 직후 `.ssafy_progress` 파일을 `init` 상태로 초기화하여 바로 목록 확인 가능

## V7.4 (2026-01-23) - Security & Stability Update 🔐

### ✨ 주요 변경 사항 (Major Changes)
- **세션 메타데이터 암호화**: `.ssafy_session_meta` 파일 내 민감 정보(Course/Practice/PA ID)를 **Base64**로 암호화하여 저장
- **토큰 입력 보안 (Secure Input)**: `gitup` 실행 시 인자가 없으면 토큰/URL을 화면에 보이지 않게 입력 (`read -s`)
- **설정 파일 보호**: 토큰 업데이트 시 데이터 손상 방지 로직 적용 (`_set_config_value`)

### 🛠 기능 개선 (Improvements)
- **Gitup Auto-Sync**: `gitup` 실행 시 이미 푼 문제의 진행 상황을 자동으로 동기화
- **설치 스크립트 개선**: `install.sh`의 정리(Cleanup) 로직을 정교화하여 기존 설정 유지

---

## V7.3 (2026-01-22) - IDE Automation & Cursor Support ⌨️

### ✨ 주요 변경 사항
- **IDE 자동 탐색**: `pycharm`, `idea`, `cursor` 명령어가 없어도 설치 경로를 자동 스캔하여 연결 (`_setup_ide_aliases`)
- **지원 IDE 목록 최적화**: 
  - **Cursor** 정식 지원 추가
  - VS Code, PyCharm, IntelliJ, Sublime Text 등 5대장 체제 확립
  - "Custom" 입력 제거 (안정성 강화)
- **UI 개선**: `algo-config show` 출력을 `algo-doctor` 스타일로 깔끔하게 정리
- **버전 통합**: 모든 도구 및 스크립트 버전을 **V7.3**으로 동기화

---

## V7.0b (Beta) (2026-01-22) - Maximum Security & UX 🔥

### 🛡️ 보안 강화 (Security)
- **설정 파일 암호화**: `.algo_config` 내 민감정보(토큰)를 **Base64**로 암호화하여 저장
- **권한 강제**: 설정 파일 권한을 `600` (타인 접근 불가)으로 자동 설정

### ✨ UX/편의성 (Usability)
- **설정 마법사 (`algo_config_wizard.py`)**: `algo-config edit` 시 직관적인 GUI(TUI) 제공
- **Smart Copy**: 브라우저 북마크릿을 통해 `URL|Token` 통합 복사 지원 데이터 포맷 처리
- **Secure Input**: `gitup`을 인자 없이 실행 시 **보안 입력 모드**로 진입 (토큰 화면 노출 방지)
- **시스템 진단**: `algo-doctor` 명렁어로 설정 상태 및 오류 원인 자동 분석

---

## V6.1 (2026-01-21) - User Experience Upgrade ✨

### ✨ 주요 기능
- **IDE 설정 대화형 지원**: 설치 및 업데이트 시 **대화형 메뉴**를 통해 선호하는 IDE(VS Code, PyCharm, IntelliJ)를 간편하게 선택
- **IDE 설정 단순화**: 프로세스 감지 방식 대신 설정 파일(`~/.algo_config`)에서 단일 IDE 지정 (`IDE_EDITOR="code"`)
- **일괄 Push (`gitdown --all`)**: SSAFY 세션 루트에서 하위 모든 실습실을 한 번에 add -> commit -> push
- **제출 바로가기**: `gitdown` 완료 시 해당 문제의 제출 페이지 URL 출력 및 브라우저 열기 옵션 제공
- **동적 Playlist**: 아직 풀지 않은 문제(Git 커밋이 없는 폴더)를 자동 감지하여 이동 제안

### 📝 개선 사항
- `ssafy_batch_create.py` 파이프라인 데이터 포맷 변경으로 메타데이터 연동 강화

---

## V6 (2026-01-20) - One-liner Installer 🚀

### ✨ 주요 기능
- **원라이너 설치**: 터미널에 한 줄만 입력하면 자동 설치 및 설정
  ```bash
  bash <(curl -sL https://raw.githubusercontent.com/junDevCodes/SSAFY_sh_func/main/install.sh)
  ```
- **동적 경로 지원**: 하드코딩된 경로 제거로 어디에 설치해도 정상 동작
- **설치 시 자동 설정**: 설치 중 SSAFY GitLab 사용자명 입력 및 자동 적용
- **algo-update 명령어**: `algo-update`로 간편하게 최신 버전 업데이트
- **자동 업데이트 알림**: 하루 1회 백그라운드에서 새 버전 체크 후 알림

### 🐛 버그 수정
- Python 3.6 하위 버전 호환성 추가

### 📁 신규 파일
- `install.sh` - 자동 설치 스크립트
- `updatenote.md` - 버전별 변경사항 문서

### 🛠️ 추가 업데이트 (Hotfixes)
- **macOS 설치 지원**: `install.sh`의 `sed` 호환성 문제 해결 (모든 OS 지원)
- **CI/CD 구축**: GitHub Actions를 통한 자동 테스트 환경 구성 (`tests/` 폴더 트래킹)
- **안정성 개선**: `timeout` 명령어 호환성 확보 (Git Bash), 이모지 깨짐 수정
- **기능 확장**: `ex` 타입 SSAFY 프로젝트 인식 추가
- **코드 클린업**: 불필요한 쿠키/중복 코드 제거

### 커밋 로그
- `61923f0` Feat: Add install.sh & fixes
- `51e0825` fix: resolve critical issues (func dup, mac compat, regex, timeout)
- `3ee5822` feat: setup CI and remove cookie
- `2e7282c` fix: git add directory instead of file in al command

---

## V5 (2026-01-13 ~ 2026-01-14) - SSAFY Smart Batch

### ✨ 주요 기능
- **SSAFY 실습실 일괄 생성**: `gitup <실습실URL>`로 해당 주차 전체 문제 자동 생성 및 클론
- **메타데이터 가드**: 차시(Round) 침범 방지 - 과목/레벨 변경 자동 감지
- **토큰 만료 자동 감지**: JWT의 `exp` 클레임을 확인하여 24시간 만료 시 재입력 안내
- **Bookmarklet 토큰 복사**: 개발자 도구(F12) 없이 북마크 클릭으로 토큰 획득
- **스마트 정렬 & 플레이리스트**: ws → hw 순서 자동 정렬, `.ssafy_playlist` 파일 생성
- **자동 업데이트 체크**: 하루 1회 원격 저장소와 버전 비교

### 🐛 버그 수정
- SSAFY 서버 레포 생성 지연 시 URL 누락 문제 (재시도 로직 강화)
- Windows 환경 `UnicodeEncodeError` 해결
- `requests` 라이브러리 의존성 제거 (`urllib` 사용)

### 커밋 로그
- `4e74e09` Feat: V5 Update - SSAFY Batch & Update Notification
- `febe006` docs: image posting
- `87f14fb` feat: 차시 감지 문제 및 목록 엔딩 감지 개선
- `0396c81` docs: how to add token setting
- `bc2d4a4` feat: not to tracking other files
- `7430678` docs: token with bookmarklet
- `5d75f0a` feat: use bearer token to personalize
- `47ca9f0` fix: request 라이브러리 의존성 문제 해결
- `cf5dceb` update V5: automated workflow
- `40d3514` docs: Update README and remove debug scripts
- `f5d8577` Enhance gitup/down with smart sorting, playlist, and UI improvements
- `d189672` chore: stop tracking tests directory
- `2cfcc6e` docs: not to follow test file
- `8ce4f51` docs: add usage guide for ssafy_batch command
- `0b70621` feat: add ssafy_batch command and bump version to V5-prot
- `f487534` feat: add ssafy_batch_create.py for batch automation
- `7907cf8` feat: UPDATE V5

---

## V4 (2026-01-06 ~ 2026-01-09) - Commit Message & Branch Fix

### ✨ 주요 기능
- **커밋 메시지 커스텀**: `al b 1000 "fix: typo"` 형식으로 메시지 직접 지정
- **C++ 파일 지원**: `al b 1000 cpp`으로 C++ 템플릿 생성
- **브랜치 자동 감지**: 설정된 브랜치로 푸시 실패 시 현재 브랜치로 재시도
- **IDE 우선순위 설정**: `algo-config edit`로 VS Code, PyCharm 등 순서 지정

### 🐛 버그 수정
- 잘못된 브랜치명으로 푸시 실패하던 문제
- 커밋 메시지 확인 없이 바로 푸시되던 문제

### 커밋 로그
- `9bef9ba` update V4: gitdown default branch 오류 해결 및 브랜치 선택 등 사용자 경험 개선
- `49abc81` docs: 최종 버전에 맞춘 사용법 및 설치, 업데이트 기능 정리
- `1440f50` test: 테스트 파일 생성
- `3505f48` docs: README.md
- `b4e3c7d` docs: al 명령어 실행 시 cpp 파일도 생성하도록 변경
- `5a704fb` feat: al 명령어 실행 시 cpp 파일도 생성하도록 변경
- `8ea64cb` docs: al, gitdown commit msg 세팅 안내 추가
- `83464bf` feat: gitdown, al 명령어 사용 시 commit msg 입력/검증 가능하도록 기능 구현

---

## V3 (2025-11-16) - Branch & Commit Fix

### ✨ 주요 기능
- **브랜치 푸시 우선순위**: master → main 순서로 자동 시도
- **사용자 브랜치 선택**: 위 두 브랜치 없을 시 선택지 제공

### 🐛 버그 수정
- gitdown 커밋 메시지 작성 오류
- default 브랜치 push 오류

### 커밋 로그
- `94a6a7b` update V3: gitdown commit msg 작성 오류 및 default 브랜치 push 오류 개선
- `374f248` fix: gitdown 함수 push 우선순위 설정

---

## V2 (2025-11-16) - Windows Support & Improvements

### ✨ 주요 기능
- **브랜치 자동 감지** (main/master 자동 처리)
- **커밋 메시지 규칙 개선** (폴더명도 prefix 사용)
- **check_ide Windows 환경 지원 강화**
- **_handle_git_commit 디렉토리 복원 로직 추가**

### 커밋 로그
- `e7adfee` update V2: 알고리즘 셸 함수 개선 및 README 업데이트

---

## V1 (2025-11-12 ~ 2025-12-02) - Initial Release

### ✨ 주요 기능
- `al` - 알고리즘 문제 환경 자동 생성 (BOJ/SWEA/Programmers)
- `gitdown` - Git add/commit/push 자동화
- `gitup` - Git clone + IDE 자동 열기
- IDE 자동 감지 (VS Code, PyCharm, IntelliJ IDEA)
- `sample_input.txt` 자동 생성

### 커밋 로그
- `df99a0f` feat: 기존 bash shell 함수와 충돌 방지를 위한 대체 방식으로 변경
- `eb7737e` docs: README
- `8b72d2c` first commit
