# VERSION 자동화 작업 보고서

## 개요
- **목표**: 버전을 루트 `VERSION` 파일로 단일 진실 공급원(SSOT)화하고, 릴리즈 시 Git Tag와 `VERSION` 값 불일치를 CI에서 차단
- **기준 버전**: `V8.1.2`

## 작업 범위 및 결과

### 1) 루트 `VERSION` 파일 생성 (SSOT)
- **추가 파일**: `VERSION`
- **내용**: 한 줄 버전 문자열 `V8.1.2`
- **의도**: 스크립트/CI가 동일한 버전 소스를 참조하도록 통합

### 2) `algo_functions.sh`가 `VERSION`을 읽도록 수정
- **변경 파일**: `algo_functions.sh`
- **변경 내용**
  - `SCRIPT_DIR` 계산 직후 `VERSION` 파일을 읽어 `ALGO_FUNCTIONS_VERSION`을 설정
  - `VERSION` 파일이 없거나 읽기 실패/빈 값이면 기존 기본값(`ALGO_FUNCTIONS_VERSION_DEFAULT`)으로 폴백
  - Windows(Git Bash) 환경을 고려하여 CRLF(`\r`) 및 공백 제거 처리

### 3) `install.sh`가 `VERSION`을 읽도록 수정
- **변경 파일**: `install.sh`
- **변경 내용**
  - 저장소 clone 이후 설치 경로의 `VERSION` 파일을 읽어 설치 완료 메시지에 표시
  - 파일이 없거나 읽기 실패 시 `Unknown`으로 표시
  - CRLF(`\r`) 및 공백 제거 처리

### 4) 릴리즈 시 Tag ↔ VERSION 일치 검증 CI 추가
- **추가 파일**
  - `ci/check_tag_matches_version.sh`: 태그명과 `VERSION` 값 비교 스크립트
  - `.github/workflows/release-version-check.yml`: `V*` 태그 push 시 검증 실행
- **동작**
  - 태그 푸시(`V8.1.2` 등) 시 워크플로우가 실행됨
  - `./ci/check_tag_matches_version.sh "${GITHUB_REF_NAME}"`로 비교
  - 불일치/누락/빈 값이면 **실패(exit 1)** 로 릴리즈 파이프라인 차단

## 로컬 검증 가이드(수동)
- **버전 로드 확인**: 새 셸에서 `source ./algo_functions.sh` 실행 후 출력에 `(V8.1.2)`가 표시되는지 확인
- **스크립트 단독 검증**:
  - `bash ./ci/check_tag_matches_version.sh V8.1.2` (성공)
  - `bash ./ci/check_tag_matches_version.sh V0.0.0` (실패)

## 변경 파일 목록
- **추가**
  - `VERSION`
  - `ci/check_tag_matches_version.sh`
  - `.github/workflows/release-version-check.yml`
  - `results/VERSION_AUTOMATION_REPORT.md`
- **수정**
  - `algo_functions.sh`
  - `install.sh`

