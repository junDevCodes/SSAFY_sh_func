# 📋 업데이트 노트 (Release Notes)

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

### 🐛 버그 수정
- Python 3.6 하위 버전 호환성 추가

### 📁 신규 파일
- `install.sh` - 자동 설치 스크립트
- `updatenote.md` - 버전별 변경사항 문서

### 커밋 로그
- `61923f0` Feat: Add install.sh & fixes

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
