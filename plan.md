# 통합 개선 작업 계획

## V8.2.x 4개 이슈 계획 (2026-02-25)

### 목표
- [ ] 이슈 1(`algo-update --force`) 동작을 회귀 테스트로 고정한다.
- [ ] 이슈 2(`gitdown` 기본 동작) 동작을 회귀 테스트로 고정한다.
- [ ] 이슈 3(`gitdown` 패널 begin/end 누락)을 코드로 수정한다.
- [ ] 이슈 4(업데이트 백업 정리 시점)를 코드로 수정한다.

### 구현 범위
- [ ] `lib/git.sh`: `gitdown` 패널 출력 흐름 정리
- [ ] `lib/update.sh`: 백업 정리 시점/보존 정책 수정
- [ ] `tests/test_update_flow.sh`: 업데이트 회귀 테스트 3건 추가
- [ ] `tests/test_commands_integration.sh`: `gitdown` 회귀 테스트 3건 추가
- [ ] `updatenote.md`: 릴리즈 노트 반영

### 세부 체크리스트
#### 이슈 1 — `algo-update --force`
- [ ] 동일 버전/동일 ref에서도 `--force` 시 swap 경로가 실행되는지 검증한다.

#### 이슈 2 — `gitdown` 기본 동작
- [ ] 세션 루트에서 `gitdown` 기본 실행 시 `_gitdown_all`로 진입하는지 검증한다.
- [ ] 하위 폴더에서 `GIT_AUTO_PUSH=false`여도 commit 성공 후 follow-up이 실행되는지 검증한다.

#### 이슈 3 — `gitdown` 패널화
- [ ] `git status --short`를 `ui_info` 라인 출력으로 전환한다.
- [ ] 첫 입력 프롬프트 전 `ui_panel_end`로 패널을 flush한다.
- [ ] 최종 확인 패널도 `input_confirm` 전에 `ui_panel_end`로 닫는다.
- [ ] commit/push 이후 결과 패널(`begin/end`)을 분리한다.
- [ ] begin/end 짝 회귀 테스트를 추가한다.

#### 이슈 4 — 업데이트 백업 누적
- [ ] `_ssafy_swap_with_backup`의 백업 정리 루프를 swap 성공 후로 이동한다.
- [ ] 새로 만든 `backup_dir`는 삭제 대상에서 제외한다.
- [ ] 글롭 미매칭 안전 처리(`-e` 체크)를 적용한다.
- [ ] 실패 시 기존 백업 보존 테스트를 추가한다.

### 테스트
- [ ] `bash tests/test_update_flow.sh`
- [ ] `bash tests/test_commands_integration.sh`
- [ ] `bash tests/test_gitup_flow.sh`

### 수동 확인
- [ ] `algo-update --force`가 조기 종료 없이 재설치를 진행하는지 확인
- [ ] 세션 루트 `gitdown`에서 batch 처리 후 제출 링크 흐름 확인
- [ ] 하위 폴더 `gitdown` + `GIT_AUTO_PUSH=false`에서 follow-up 흐름 확인
- [ ] `gitdown` 단계별 패널 flush/종료 동작 확인
