# 📋 업데이트 노트 (Release Notes)

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
