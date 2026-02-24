# ?? 업데이트 노트 (Release Notes)

## V8.1.7 (2026-02-24) - Stability Hotfix

### ? algo-update 입력 흐름 버그 수정
- 원인: `input_confirm` 호출 시 출력 변수(`answer`) 반영이 누락될 수 있는 변수 스코프 충돌.
- 증상: `algo-update`에서 `y`를 입력해도 즉시 종료되는 케이스 발생.
- 수정: `input_confirm` 내부 입력 임시 변수명을 분리하여 호출자 변수 반영 보장.

### ? 설치/업데이트 안정성 강화
- snapshot 업데이트 후 적용 메타(`mode/channel/ref/version`) 확인 경로 강화.
- 설치 후 설정 플로우는 GUI 우선, 실패 시 CLI fallback 정책 유지.

### ? 회귀 방지 테스트 추가
- `tests/test_input_confirm_scope.sh` 추가.
- `tests/run_tests.sh`, `tests/run_tests.ps1`에 스위트 연동.

---

## V8.1.7 (2026-02-24) - Integrated Improvements

### 주요 변경
- `gitup` Step 4 흐름 안정화 (`b=back` 복귀, confirm 분기 정리).
- SmartLink(`URL|Token`) 경로 처리 및 디버그 추적 강화.
- `algo-help` 중심 도움말 정책 정리, hint 출력 최소화.
- 패널 렌더링 성능 개선(배치 렌더/폴백 경로 보강).

### 문서/버전
- `VERSION` 및 문서 버전 `V8.1.7` 동기화.

---

## V8.1.6 (2026-02-20) - UI Alignment Stabilization

### 주요 변경
- VS Code Git Bash 환경의 panel 우측 경계 정렬 오차 완화.
- `ALGO_UI_EMOJI_WIDTH=auto|narrow|wide` 도입.
- `algo-config`, `algo-doctor` 패널 출력 정렬 안정성 개선.

---

## V8.1.5 (2026-02-19 ~ 2026-02-20) - Installer/Update Foundation

### 주요 변경
- 설치 기본 방식을 snapshot 기반으로 전환.
- `algo-update` 하이브리드 전략(snapshot/git/legacy-git) 도입.
- legacy git 설치 자동 마이그레이션 경로 추가.

---

## 과거 버전

이전 상세 릴리즈 노트(V8.1.4 이하)는 별도 문서 정리 이후 순차 복원 예정입니다.
핵심 운영 이력은 Git 커밋 로그로 추적할 수 있습니다.