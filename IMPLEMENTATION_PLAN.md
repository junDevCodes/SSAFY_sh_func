# IMPLEMENTATION PLAN

## 1. 문제 정의

### 1.1 설치 설정 누락
- 초기 설치 후 사용자 설정이 부분적으로만 채워져 핵심 동작 전 에러가 발생할 수 있다.

### 1.2 TUI 지연
- panel 출력 시 줄 단위 Python subprocess 실행으로 출력이 느리게 보인다.

### 1.3 도움말 분산
- 힌트가 범용 도움말까지 담당하여 정보가 분산되어 있다.

## 2. 설계

### 2.1 설치 완료 플로우
- 설치 종료 직후 별도 설정 완료 플로우를 실행한다.
- 핵심 7개는 사용자 입력/선택으로 설정한다.
  - `ALGO_BASE_DIR`
  - `IDE_EDITOR`
  - `GIT_DEFAULT_BRANCH`
  - `GIT_COMMIT_PREFIX`
  - `GIT_AUTO_PUSH`
  - `SSAFY_BASE_URL`
  - `SSAFY_USER_ID`
- 부가 4개는 안내만 출력하고 미설정 시 기본값 유지:
  - `SSAFY_UPDATE_CHANNEL=stable`
  - `ALGO_UI_STYLE=panel`
  - `ALGO_UI_COLOR=auto`
  - `ALGO_INPUT_PROFILE=stable`

### 2.2 UI 배치 렌더
- panel 오픈 시 출력 라인을 내부 버퍼에 저장한다.
- panel 종료 시 버퍼를 한 번에 렌더한다.
- Python backend 사용 가능 시 1회 실행으로 처리한다.
- Python 불가 시 shell plain 포맷으로 폴백한다.

### 2.3 algo-help 도입
- `ssafy_algo_help` 함수 + `algo-help` alias를 추가한다.
- 기본 출력: 전체 명령어 요약 + 대표 예시 + 링크 테이블
- 상세 출력: `algo-help <command>`
- 링크 정책:
  - `gitup`, `gitdown`: `https://jundevcodes.github.io/SSAFY_sh_func/guide.html`
  - `al`: `https://jundevcodes.github.io/SSAFY_sh_func/alias.html`

### 2.4 hint 정책 축소
- 다음 행동과 직접 연결된 경우에만 hint를 유지한다.
- 범용 안내는 `algo-help`로 이관한다.

## 3. 파일별 변경
- `install.sh`: post-install setup, 핵심 7개 수집, 부가 4개 안내
- `lib/config.sh`: 기본값 일관성 및 부가 4개 기본값 보장
- `lib/ui.sh`: panel buffer + batch renderer + flush 구조
- `lib/help.sh`: 신규 help 모듈
- `algo_functions.sh`: help 모듈 로드, alias 등록, 시작 hint 정리
- `README.md`: 설치/도움말/hint 정책 변경 문서화
- `plan.md`: 실행 체크리스트 유지

## 4. 테스트/수용 기준
1. 설치 후 설정 플로우가 자동 시작되어야 한다.
2. 핵심 7개 설정이 실제 config 파일에 반영되어야 한다.
3. 부가 4개 미설정 시 기본값이 유지되어야 한다.
4. panel 출력은 배치 렌더 경로를 사용해야 한다.
5. `algo-help`가 요약/예시/링크를 제공해야 한다.
6. hint는 연계형 시나리오에서만 제한적으로 출력되어야 한다.
7. 기존 테스트가 통과해야 한다.

## 5. 호환성/롤백
- 기존 명령(`al`, `gitup`, `gitdown`, `algo-config`, `algo-update`, `algo-doctor`) 인터페이스는 유지한다.
- UI 배치 렌더 실패 시 plain 포맷으로 자동 폴백한다.
- 설치 플로우 중단 시 기존/기본 설정으로 안전하게 유지한다.
