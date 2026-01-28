# QC 테스트 보고서 (2026-01-28)

## 개요

- **대상 프로젝트**: `SSAFY_sh_func`
- **테스트 목적**: 팀원 산출물에 대한 수동/반자동 QC 3종 수행 및 결과 기록
- **테스트 수행일**: 2026-01-28
- **기준 리비전(참고)**: `eb4f29e`
- **테스트 환경**
  - **OS**: Windows 10 (build 26200)
  - **Shell**: Git Bash (`bash`)

## 결론 요약

- **QC 1 (Windows CRLF 개행)**: **PASS**
- **QC 2 (설치 실패 시뮬레이션)**: **PASS (재테스트)**  
  - (참고) 출력 문구에 문자열 **`설치 실패`**가 정확히 포함되진 않음(의미상 실패 안내는 출력됨)
- **QC 3 (진단 리포트 복사/붙여넣기 포맷)**: **PASS (단, GitHub Issue Preview 직접 확인은 로그인 제약으로 API 렌더링으로 대체 확인)**

---

## QC 1. Windows(Git Bash) 개행 테스트 (VERSION CRLF)

### 테스트 목적

- `VERSION` 파일이 **CRLF(\r\n)** 로 오염되었을 때, `algo_functions.sh` 로드 메시지 및 버전 출력에 **`\r`(예: `^M`) 같은 이상 문자가 붙지 않는지** 확인.

### 기대 결과

- `source ./algo_functions.sh` 실행 시 출력되는 버전 문자열이 **정상적으로** 표시된다.
- 내부 변수 `ALGO_FUNCTIONS_VERSION` 값에 `\r` 등이 포함되지 않는다.

### 수행 절차(재현)

- `VERSION` 파일을 CRLF로 강제 작성 후, Git Bash에서 `algo_functions.sh` 로드 및 변수 값을 출력하여 확인.

### 실행 로그(근거)

```bash
# VERSION 파일을 CRLF로 작성(시뮬레이션)
python -c "open('VERSION','wb').write(b'V8.1.2\r\n')"

# 로드 후 변수 출력
bash -lc 'source ./algo_functions.sh; printf "ALGO_FUNCTIONS_VERSION=%q\n" "$ALGO_FUNCTIONS_VERSION"'
```

```text
✅ 알고리즘 셸 함수 로드 완료! (V8.1.2)
💡 'algo-config edit'로 설정을 변경할 수 있습니다
✅ 알고리즘 셸 함수 로드 완료! (V8.1.2)
💡 'algo-config edit'로 설정을 변경할 수 있습니다
ALGO_FUNCTIONS_VERSION=V8.1.2
```

### 결과

- **PASS**
- 버전 출력/변수 값 모두 **`\r` 없는 정상 문자열**로 확인됨.
- 참고: `algo_functions.sh`는 `VERSION` 로드 시 `\r` 제거 및 공백 제거 로직이 포함되어 있음.

---

## QC 2. 설치 실패 시뮬레이션 (clone 실패 시 VERSION 로직/메시지)

### 테스트 목적

- `install.sh` 실행 중 네트워크 장애 등으로 `git clone`이 실패했을 때,
  - (A) `VERSION` 파일 읽기 로직이 **터지지 않고**
  - (B) 사용자에게 **"설치 실패" 메시지**가 명확하게 출력되는지 확인.

### 기대 결과

- `git clone` 실패 시에도 스크립트가 **의도된 실패 처리 경로로 진입**한다.
- 사용자에게 **"설치 실패"**(또는 이에 준하는 명확한 실패 안내) 메시지를 출력한다.
- 비정상 종료(예: 미정의 변수 참조, 잘못된 파일 접근) 없이 **정상적인 에러 처리**로 종료한다.

### 수행 절차(재현)

- 실제 인터넷 차단 대신, `git` 함수를 오버라이드하여 `git clone`이 실패하도록 시뮬레이션(동등한 실패 조건).

### 실행 로그(근거)

```bash
bash -lc '
  export HOME="$PWD/.qc_home"
  mkdir -p "$HOME"

  # git clone 실패 시뮬레이션
  git(){ echo "simulated: git clone failed" >&2; return 128; }
  export -f git

  bash ./install.sh
  echo "EXIT_CODE=$?"
'
```

```text
🚀 SSAFY Shell Functions 설치를 시작합니다...

simulated: git clone failed
📥 저장소 다운로드 중...
EXIT_CODE=128
```

### 관찰 사항 / 이슈

- `install.sh` 상단의 `set -e`로 인해 `git clone` 실패 즉시 **스크립트가 중단**됨.
- 그 결과:
  - 기대한 **"설치 실패" 메시지**가 출력되지 않음 (**요구사항 미충족**)
  - `VERSION` 파일 읽기 로직(2-1 절)까지 도달하지 않아, “VERSION 읽기 로직이 터지지 않는다”는 요구는 **경로 자체가 실행되지 않아 검증 불가** 상태.

### 결과

- **(1차) FAIL**
- “설치 실패” 메시지 출력 요구를 만족하지 못함.

### 개선 제안(원인 기반)

- `git clone` 구간을 `if ! git clone ...; then ...; fi` 형태로 감싸서,
  - `set -e` 환경에서도 **사용자 친화적인 실패 메시지**를 출력하고,
  - 명시적으로 `exit 1` 하도록 개선 필요.
- 예시(의도):
  - `echo "❌ 설치 실패: 저장소 다운로드에 실패했습니다. 네트워크를 확인해주세요." >&2`

### 재테스트 (install.sh 수정 후)

#### 재테스트 목적

- `git clone` 실패 시에도 스크립트가 즉시 종료되지 않고, **실패 메시지를 출력한 뒤 정상적으로 종료(exit 1)** 하는지 확인.

#### 실행 로그(근거)

```bash
bash -lc '
  export HOME="$PWD/.qc_home2"
  mkdir -p "$HOME"

  # git clone 실패 시뮬레이션
  git(){ echo "simulated: git clone failed" >&2; return 128; }
  export -f git

  bash ./install.sh
  rc=$?
  echo "EXIT_CODE=$rc"
'
```

```text
🚀 SSAFY Shell Functions 설치를 시작합니다...

simulated: git clone failed
📥 저장소 다운로드 중...

❌ 저장소 다운로드에 실패했습니다. (네트워크 연결을 확인해주세요)
EXIT_CODE=1
```

#### 재테스트 결과(최종)

- **PASS (재테스트)**
- `git clone` 실패 시 **실패 메시지 출력 후 `exit 1`**로 종료됨.
- 참고: 요구사항이 “출력 문자열에 `설치 실패`가 반드시 포함”인 경우, 현재 문구는 의미상 실패 안내이지만 **정확히 `설치 실패` 문자열은 포함하지 않음**.

---

## QC 3. 진단 리포트 복사 테스트 (algo-doctor → GitHub Issue Preview)

### 테스트 목적

- `algo-doctor`가 출력하는 “복사용 진단 리포트(Markdown)”를 복사해 GitHub 이슈 입력창(Preview)에 붙여넣었을 때,
  - 코드블록이 깨지지 않고
  - 보기 좋은 포맷으로 렌더링되는지 확인.

### 기대 결과

- 리포트가 Markdown 코드블록으로 감싸져 있어 GitHub Preview에서 **정렬/개행/가독성**이 유지된다.

### 수행 절차(재현)

1. `algo_functions.sh` 로드
2. `ssafy_algo_doctor` 실행
   - 참고: 비인터랙티브 셸에서는 alias(`algo-doctor`)가 확장되지 않을 수 있어, 함수명 `ssafy_algo_doctor`를 사용(자동화/CI 환경에서 재현성 확보 목적).
3. 출력된 “복사용 진단 리포트(Markdown)” 블록을 복사
4. GitHub Issue Preview에서 렌더링 확인(시각 확인)

### 실행 로그(근거)

```bash
bash -lc 'source ./algo_functions.sh >/dev/null; ssafy_algo_doctor'
```

출력 중 “복사용 진단 리포트(Markdown)” 블록(발췌):

```text
```text
[SSAFY Algo Tools Doctor 리포트]
- 생성시각(UTC): 2026-01-28T05:40:31Z
- ALGO_FUNCTIONS_VERSION: V8.1.2
...
```
```

### GitHub Preview 시각 확인 결과

- **직접 Issue Preview UI 자동화/스크린샷 첨부는 로그인/브라우저 자동화 제약으로 수행 불가**.
- 대신 GitHub의 공식 Markdown 렌더링 API(`POST /markdown`)로 동일 Markdown을 렌더링하여,
  - 코드블록이 `<pre lang="text"><code>...</code></pre>` 형태로 정상 렌더링되는 것을 확인.

API 렌더링 응답(발췌):

```html
<pre lang="text" class="notranslate"><code class="notranslate">[SSAFY Algo Tools Doctor 리포트]
- 생성시각(UTC): 2026-01-28T05:40:31Z
- ALGO_FUNCTIONS_VERSION: V8.1.2
</code></pre>
```

### 결과

- **PASS (대체 검증)**
- GitHub 렌더러 기준으로 코드블록 포맷이 정상이며, Issue Preview에서도 동일하게 깨지지 않을 가능성이 높음.

---

## 부록

### 테스트 중 변경/원복 사항

- QC 1 재현을 위해 `VERSION`을 일시적으로 CRLF로 작성했으며, 테스트 후 **LF로 원복**함.

