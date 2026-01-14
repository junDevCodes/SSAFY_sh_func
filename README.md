# 알고리즘/실습 자동화 Shell 함수 (V5)

이 저장소는 Bash 함수 3가지를 제공합니다.
1) al: 알고리즘 문제 풀이 보조
2) gitup/gitdown: 실습 제출용 Git 작업 자동화
3) ssafy_batch: 일괄 실습실 생성 및 자동화

---

## 1) al - 알고리즘 문제 풀이 보조

### 사용법
```bash
al <site> <problem> [py|cpp] [--msg <msg> | <msg>] [--no-git] [--no-open]
```

- site: `s|swea`, `b|boj`, `p|programmers`
- problem: 숫자만 허용
- language: `py`(기본값) 또는 `cpp`

### 동작
- `ALGO_BASE_DIR/<site>/<problem>/` 디렉터리를 만들고 파일을 생성합니다.
- 언어를 지정하지 않으면 `py/cpp` 파일 존재 여부에 따라 커밋을 자동 분기합니다.
- IDE를 감지해서 자동으로 파일을 엽니다(`--no-open`로 끔).

예시 구조:
```
$ALGO_BASE_DIR/
  swea/1234/swea_1234.py
  boj/10950/boj_10950.py
  programmers/42576/programmers_42576.py
```

옵션:
- `--no-git`: Git 커밋/푸시 생략
- `--no-open`: IDE 자동 열기 생략
- `--msg, -m <msg>` 또는 `<msg>`: 커밋 메시지 지정

참고:
- 커밋 메시지를 직접 넣으면 커밋 전 확인 프롬프트가 뜹니다. `n`을 선택하면 메시지를 다시 입력합니다.
- 메시지에 공백이 있으면 따옴표로 감싸세요. 예: `al b 1000 "feat: new commit"`
- `py`/`cpp`로 생성할 때는 빈 `sample_input.txt`가 함께 만들어집니다.
- 언어를 지정하지 않으면, `py/cpp` 파일 존재 여부에 따라 커밋을 자동으로 분기합니다(둘 다 있으면 각각 따로 커밋).
- `al b 1000`처럼 언어를 생략해도 `py/cpp`가 둘 다 있으면 각각 한 번씩 커밋됩니다.

---

## 2) gitup / gitdown - 실습 제출용

### gitup
```bash
gitup <git-repository-url | ssafy-topic>
gitup --ssafy <ssafy-topic>
```
- 저장소를 clone 한 뒤, 루트 근처에서 적당한 파일을 찾아 IDE로 엽니다.
- 파일이 여러 개면 `py/ipynb/cpp` 파일 목록을 우선 보여주고, 필요하면 트리(번호 선택)로 다른 파일도 열 수 있습니다.
- SSAFY 전용 모드에서는 같은 주제/차시의 `ws(1~5)`, `hw(2,4)`를 한 번에 클론합니다.
- **NEW**: `project.ssafy.com` 실습실 링크를 넣으면, **실습실 1~7번 자동 생성 + 전체 클론 + 1번 문제 실행**까지 한 번에 처리합니다.
- **Smart Sorting**: 실습(ws) -> 과제(hw) 순서로 정렬하며, 생성 시간(PA ID)을 기준으로 정확한 순서를 보장합니다.
- **Playlist**: `gitup` 실행 시 `.ssafy_playlist` 파일을 생성하여 `gitdown`이 순서대로 이동하도록 돕습니다.
- 없는 저장소는 건너뛰고 요약만 출력합니다.
- `data_ws`처럼 주제만 넣으면 차시 번호를 입력받습니다.

SSAFY 예시:
```bash
# [추천] 링크 하나로 생성부터 클론까지 끝내기
gitup https://project.ssafy.com/practiceroom/.../answer/PA...

# 기존 방식
gitup data_ws
gitup https://lab.ssafy.com/jylee1702/data_ws_4_1
gitup --ssafy data_ws
```
SSAFY 기본 주소와 사용자 ID는 `~/.algo_config`에서 변경할 수 있습니다.
처음 실행 시 `SSAFY_BASE_URL`/`SSAFY_USER_ID`를 입력받아 `~/.algo_config`에 저장합니다.

### gitdown
```bash
gitdown [commit message]
gitdown --ssafy [commit message]
gitdown --msg <message>
```
- `git add .` → `git commit` → `git push` → `cd ..`
- 기본 커밋 메시지: `${GIT_COMMIT_PREFIX}: <현재폴더명>`
- `GIT_AUTO_PUSH=true`일 때만 자동 push 수행
- 커밋 메시지를 직접 넣으면 커밋 전 확인 프롬프트가 뜹니다. `n`을 선택하면 메시지를 다시 입력합니다.
- 메시지에 공백이 있으면 따옴표로 감싸세요. 예: `gitdown "feat: new commit"`
- `--ssafy` 옵션을 쓰면 push 성공 시에만 다음 문제 디렉터리로 자동 이동하고 IDE를 엽니다.
- `--ssafy`는 현재 폴더명이 `<주제>_(ws|hw)_<차시>_<문제번호>` 형식일 때 동작합니다.
- `gitup --ssafy`로 클론한 루트를 `.ssafy_session_root`로 기록하고, `gitdown --ssafy`는 해당 루트를 기준으로 이동합니다.
- **Smart Navigation**: `gitup`이 생성한 플레이리스트 순서대로 정확하게 다음 문제로 이동합니다.
- **Completion Message**: 모든 문제를 다 풀면 "OO 과목의 해당 차시가 종료되었습니다" 메시지를 출력합니다.

푸시 브랜치 결정 규칙:
- 원격 default 브랜치(`origin/HEAD`)를 우선 사용합니다.
- 로컬에 `master`와 `main`이 **둘 다 있거나 둘 다 없으면** 브랜치 목록을 보여주고 선택합니다.
- 로컬에 `master` 또는 `main`이 **하나만** 있고, 그것이 원격 default와 같으면 자동으로 푸시합니다.

---

## 3) ssafy_batch - SSAFY 실습실 자동 생성

### 사용법
```bash
ssafy_batch <URL> [COUNT]
```
- `URL`: 브라우저 주소창에 보이는 실습실 문제 링크 (예: `.../answer/PA...`)
- `COUNT`: 생성할 문제 개수 (기본값: 7)

### 동작
1. 입력된 URL에서 문제 ID와 과목 ID를 자동으로 감지합니다.
2. 만약 특정 문제(예: 3번) 링크라면, 지능적으로 앞번호(1번)부터 스캔하도록 자동 보정합니다.
3. 연속된 번호(예: 1번~7번)에 대해 '실습 시작' 요청을 자동으로 보냅니다.
4. 이미 생성된 레포지토리는 건너뛰고, 없는 것만 새로 생성합니다.

### 주의사항
- `ssafy_batch_create.py` 파일의 위치가 `c:/Users/SSAFY/Desktop/SSAFY_sh_func/`로 고정되어 있습니다. 파일 위치가 다르면 `algo_functions.sh` 내 경로를 수정해야 합니다.
- 내부 `HEADERS` 토큰(로그인 정보)이 만료되면 동작하지 않을 수 있습니다. (이 경우 스크립트 파일을 열어 토큰을 갱신해야 합니다.)

---

## 설치 및 적용 (권장)

이 스크립트는 **파일 복사** 방식으로 사용하는 것을 권장합니다.

### 1) 파일 위치 결정
```bash
mkdir -p ~/scripts
# 스크립트 파일 2개를 모두 복사해야 합니다.
cp ./algo_functions.sh ./ssafy_batch_create.py ~/scripts/
```

### 2) 셸 설정 파일에 source 추가
```bash
echo 'source ~/scripts/algo_functions.sh' >> ~/.bashrc
# zsh 사용 시
# echo 'source ~/scripts/algo_functions.sh' >> ~/.zshrc
```

### 3) 적용
```bash
source ~/.bashrc
```

---

## 업데이트

기존 파일을 덮어쓰면 됩니다.
```bash
cp ./algo_functions.sh ./ssafy_batch_create.py ~/scripts/
source ~/.bashrc
```

---

## 설정 파일

- 위치: `~/.algo_config`
- 명령어:
```bash
algo-config show
algo-config edit
algo-config reset
```

주요 설정값:
```bash
ALGO_BASE_DIR="$HOME/algorithm"
GIT_COMMIT_PREFIX="solve"
GIT_AUTO_PUSH=true
IDE_PRIORITY="code pycharm idea subl"
SSAFY_BASE_URL="https://lab.ssafy.com"   # 처음 실행 시 입력받음
SSAFY_USER_ID="your-id-or-namespace"     # 예: group/user
```

---

## 테스트 실행

```bash
# Bash 테스트(가능한 환경)
bash tests/run_tests.sh

# Windows PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1

# 자동 선택 + 결과 JSON 저장(권장)
python tests/run_tests.py --out tests/test_results.json
```
