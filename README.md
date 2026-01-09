# 알고리즘/실습 자동화 Shell 함수

이 저장소는 Bash 함수 2가지를 제공합니다.
1) al: 알고리즘 문제 풀이 보조
2) gitup/gitdown: 실습 제출용 Git 작업 자동화

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
- SSAFY 전용 모드에서는 같은 주제/차시의 `ws(1~5)`, `hw(2,4)`를 한 번에 클론합니다.
- 없는 저장소는 건너뛰고 요약만 출력합니다.
- `data_ws`처럼 주제만 넣으면 차시 번호를 입력받습니다.

SSAFY 예시:
```bash
gitup data_ws
gitup https://lab.ssafy.com/jylee1702/data_ws_4_1
gitup --ssafy data_ws
```
SSAFY 기본 주소와 사용자 ID는 `~/.algo_config`에서 변경할 수 있습니다.

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

푸시 브랜치 결정 규칙:
- 원격 default 브랜치(`origin/HEAD`)를 우선 사용합니다.
- 로컬에 `master`와 `main`이 **둘 다 있거나 둘 다 없으면** 브랜치 목록을 보여주고 선택합니다.
- 로컬에 `master` 또는 `main`이 **하나만** 있고, 그것이 원격 default와 같으면 자동으로 푸시합니다.

---

## 로컬 적용(설치)

### 1) 파일 위치 결정
```bash
mkdir -p ~/scripts
cp /path/to/algo_functions.sh ~/scripts/
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

## 업데이트 방법

### 1) 저장소에서 바로 쓰는 경우
```bash
cd /path/to/SSAFY_sh_func
git pull
source ~/.bashrc
```

### 2) 복사해서 쓰는 경우
```bash
cp ./algo_functions.sh ~/scripts/
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
SSAFY_BASE_URL="https://lab.ssafy.com"
SSAFY_USER_ID="jylee1702"
```
