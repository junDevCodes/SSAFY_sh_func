# 알고리즘/실습 자동화 Shell 함수

이 저장소는 Bash 함수 2가지를 제공합니다.
1) al: 알고리즘 문제 풀이 보조
2) gitup/gitdown: 실습 제출용 Git 작업 자동화

---

## 1) al - 알고리즘 문제 풀이 보조

### 사용법
```bash
al <site> <problem> [--msg <msg> | <msg>] [--no-git] [--no-open]
```

- site: `s|swea`, `b|boj`, `p|programmers`
- problem: 숫자만 허용

### 동작
- `ALGO_BASE_DIR/<site>/<problem>/` 디렉터리를 만들고 템플릿 파일을 생성합니다.
- 파일이 이미 있으면 필요 시 Git 커밋을 수행합니다.
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
- 템플릿에서 `sample_input.txt`를 열도록 설정되어 있지만, 파일은 자동 생성되지 않습니다.

---

## 2) gitup / gitdown - 실습 제출용

### gitup
```bash
gitup <git-repository-url>
```
- 저장소를 clone 한 뒤, 루트 근처에서 적당한 파일을 찾아 IDE로 엽니다.

### gitdown
```bash
gitdown [commit message]
```
- `git add .` → `git commit` → `git push` → `cd ..`
- 기본 커밋 메시지: `${GIT_COMMIT_PREFIX}: <현재폴더명>`
- `GIT_AUTO_PUSH=true`일 때만 자동 push 수행
 - 커밋 메시지를 직접 넣으면 커밋 전 확인 프롬프트가 뜹니다. `n`을 선택하면 메시지를 다시 입력합니다.
 - 메시지에 공백이 있으면 따옴표로 감싸세요. 예: `gitdown "feat: new commit"`

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
cp /path/to/SSAFY_sh_func/algo_functions.sh ~/scripts/
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
```
