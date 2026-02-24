# 통합 개선 작업 계획

## 목표
- [ ] 설치 완료 후 설정 완료 플로우 자동 실행
- [ ] 핵심 7개 항목 입력/선택 반영
- [ ] 부가 4개 항목 안내 및 기본값 유지
- [ ] TUI panel 배치 렌더 적용
- [ ] algo-help 명령 추가 및 hint 정책 정리

## 테스트 우선 체크리스트

### 1. 설치 설정 플로우
- [ ] 설치 완료 시 post-install setup이 호출되어야 한다 (`install.sh`)
- [ ] 핵심 7개 입력값이 `~/.algo_config`에 반영되어야 한다 (`install.sh`, `lib/config.sh`)
- [ ] 부가 4개 항목 미설정 시 기본값이 유지되어야 한다 (`install.sh`, `lib/config.sh`)

### 2. TUI 성능
- [ ] panel 모드에서 line-by-line Python 호출 대신 배치 렌더를 사용해야 한다 (`lib/ui.sh`)
- [ ] Python 불가 환경에서 plain 폴백이 동작해야 한다 (`lib/ui.sh`)

### 3. Help/Hint 정책
- [ ] `algo-help` 기본 출력에 명령어 요약/예시/링크가 포함되어야 한다 (`lib/help.sh`)
- [ ] `algo-help <command>`가 명령별 안내를 출력해야 한다 (`lib/help.sh`)
- [ ] hint는 연계형 안내만 출력되도록 축소되어야 한다 (`algo_functions.sh`, `lib/config.sh`)

### 4. 회귀 확인
- [ ] 기존 테스트(`tests/run_tests.sh`, `tests/run_tests.ps1`)가 통과해야 한다
