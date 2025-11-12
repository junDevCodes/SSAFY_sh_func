# 알고리즘 문제 풀이 (Algorithm Problem Solutions)

이 저장소는 다양한 온라인 저지 및 플랫폼의 알고리즘 문제 풀이 코드를 담고 있습니다. 
**셸 함수(Shell Functions)**를 통해 문제 풀이 환경 설정과 Git 작업이 자동화됩니다.

---

## 📋 목차

- [디렉토리 구조](#디렉토리-구조-directory-structure)
- [포함된 플랫폼](#포함된-플랫폼-included-platforms)
- [셸 함수 설치 및 사용법](#셸-함수-설치-및-사용법)
- [워크플로우 예시](#워크플로우-예시)
- [기여](#기여-contribution)

---

## 디렉토리 구조 (Directory Structure)

문제 풀이 코드는 플랫폼 및 문제 번호별로 정리되어 있습니다.

```
Algorithm-Practics(사용자 디렉토리)/
├── swea/
│   └── 1234/
│       ├── swea_1234.py
│       └── sample_input.txt
├── boj/
│   └── 10950/
│       ├── boj_10950.py
│       └── sample_input.txt
└── programmers/
    └── 42576/
        └── programmers_42576.py
```

---

## 포함된 플랫폼 (Included Platforms)

현재 다음 플랫폼들의 문제 풀이를 관리하고 있습니다:

* **SWEA** (Samsung SW Expert Academy) - `s` 또는 `swea`
* **BOJ** (백준 온라인 저지) - `b` 또는 `boj`
* **Programmers** (프로그래머스) - `p` 또는 `programmers`

---

## 셸 함수 설치 및 사용법

### 🚀 초기 설치

#### 1단계: 백업 생성 (권장)
```bash
cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)
```

#### **중요** 2단계: 셸 함수 추가
```bash
# 연습용 디렉토리 생성 위치로 설정
cd ~/Desktop/
# 사용자 문제 연습용 디렉토리 생성
mkdir Algorithm-Practics
cd Algorithm-Practics
# git init을 통한 개인 레포 설정
git init
git remote add origin "본인 레포지토리 주소"
# 다운로드 한 algo_functions.sh를 해당 디렉토리로 이동

# **중요**
# 이때의 파일구조 /사용자의 생성 위치/Algorithm-Practics/algo_functions.sh

# algo_functions.sh 파일을 다운로드한 위치에서 실행
# ~/사용자의 생성 위치/Algorithm-Practics/algo_functions.sh
cat ~/Desktop/Algorithm-Practics/algo_functions.sh >> ~/.bashrc
```

#### 3단계: 적용
```bash
source ~/.bashrc
```

#### 4단계: 설치 확인
```bash
al  # 사용법이 출력되면 성공!
```

---

### ⚙️ 설정 파일 관리

설정 파일 위치: `~/.algo_config`

#### 설정 보기
```bash
algo-config show
```

#### 설정 편집 방법

**방법 1: 명령어 사용 (추천)**
```bash
algo-config edit
```
기본 에디터(보통 nano)가 열립니다.

**방법 2: Vim 사용**
```bash
vim ~/.algo_config
```

**Vim 단축키:**
- `i` : 입력 모드 (편집 시작)
- `ESC` : 명령 모드로 돌아가기
- `:w` : 저장
- `:q` : 종료
- `:wq` 또는 `:x` : 저장 후 종료
- `:q!` : 저장하지 않고 강제 종료

**이하 초보자용 추천**

**방법 3: VSCode 사용**
```bash
code ~/.algo_config
```

**방법 4: 직접 파일 경로로 열기**
```bash
# Windows Git Bash
notepad ~/.algo_config

# macOS
open -a TextEdit ~/.algo_config

# Linux
gedit ~/.algo_config
```

#### 설정 파일 내용
```bash
# 알고리즘 문제 풀이 디렉토리 설정
ALGO_BASE_DIR="$HOME/Desktop/Algorithm-Practics"

# Git 설정
GIT_DEFAULT_BRANCH="main"           # 기본 브랜치
GIT_COMMIT_PREFIX="solve"           # 커밋 메시지 접두사
GIT_AUTO_PUSH=true                  # 자동 푸시 여부

# IDE 우선순위 (공백으로 구분)
IDE_PRIORITY="code pycharm idea subl"
```

**주요 설정 항목:**
- `ALGO_BASE_DIR`: 문제 풀이 파일이 생성될 기본 디렉토리
- `GIT_DEFAULT_BRANCH`: Git 푸시할 브랜치 (main/master)
- `GIT_COMMIT_PREFIX`: 커밋 메시지 앞에 붙을 접두사
- `GIT_AUTO_PUSH`: true면 자동 푸시, false면 수동
- `IDE_PRIORITY`: 선호하는 IDE 순서

---

### 📖 사용 가능한 명령어

#### 1. `al` - 알고리즘 문제 환경 설정

**새 문제 시작하기:**
```bash
al s 1234    # SWEA 1234번 문제
al b 10950   # BOJ 10950번 문제
al p 42576   # 프로그래머스 42576번 문제
```

**동작:**
- 새 문제: 디렉토리 생성 → Python 템플릿 파일 생성 → IDE에서 파일 열기
- 기존 문제: Git 커밋 → 푸시 → IDE에서 파일 열기

**옵션:**
```bash
al b 1000 --no-git    # Git 작업 건너뛰기
al s 2105 --no-open   # 파일 열기 건너뛰기
```

#### 2. `gitup` - Git 저장소 클론 - Git lab용

저장소를 클론하고 자동으로 파일을 열어줍니다.

```bash
gitup https://github.com/username/repo.git
```

**동작:**
1. 저장소 클론
2. 클론된 디렉토리로 이동
3. Python/HTML/README 등 파일 검색
4. 감지된 IDE에서 파일 열기


#### 3. `gitdown` - 문제 풀이 완료 - Git lab용

현재 디렉토리의 모든 변경사항을 커밋하고 푸시한 후 상위 디렉토리로 이동합니다.

```bash
gitdown                    # 자동 커밋 메시지
gitdown "custom message"   # 커스텀 커밋 메시지
```

**동작:**
1. `git add .` - 모든 변경사항 추가
2. 커밋 메시지 자동 생성 (`solve: 파일명`)
3. 커밋 및 푸시
4. `cd ..` - 상위 디렉토리로 이동

#### 4. `get_active_ide` - 활성 IDE 감지

현재 실행 중인 IDE를 감지합니다.

```bash
get_active_ide  # 예: code, pycharm, idea, subl
```

#### 5. `check_ide` - IDE 디버깅

IDE 감지 문제를 진단합니다.

```bash
check_ide
```

#### 6. `algo-config` - 설정 관리

```bash
algo-config show   # 현재 설정 보기
algo-config edit   # 설정 파일 편집
algo-config reset  # 설정 초기화
```

---

## 워크플로우 예시

### 🎯 알고리즘 새 문제 풀기

```bash
# 1. 문제 환경 설정 (새 파일 생성)
al b 1000

# 2. 코드 작성 (IDE에서 자동으로 열림)
# ... 문제 풀이 ...

# 3. 완료 후 커밋 및 상위 폴더로 이동
al b 1000
```

### 🔄 기존 문제 다시 작업

```bash
# 기존 문제 파일 열기 및 Git 커밋/푸시
al b 1000
```

### 📥 깃랩 문제 저장소 클론

```bash
gitup https://github.com/username/algorithm-solutions.git
# 자동으로 파일이 열립니다
# 문제 해결 이후
gitdown
```

---

## 🛠️ 문제 해결

### Git 푸시가 안 될 때

**1. Git 저장소 초기화 확인**
```bash
cd ~/Desktop/Algorithm-Practics
git status  # Git 저장소인지 확인
```

**2. Git 저장소 초기 설정 (처음 한 번만)**
```bash
cd ~/Desktop/Algorithm-Practics

# Git 초기화
git init

# 원격 저장소 연결
git remote add origin https://github.com/본인아이디/Algorithm-Practics.git

# 첫 커밋
git add .
git commit -m "init: 알고리즘 저장소 초기화"
git branch -M main
git push -u origin main
```

**3. 브랜치 확인**
```bash
algo-config show  # GIT_DEFAULT_BRANCH 확인
git branch        # 현재 브랜치 확인
```

브랜치가 다르면 설정 파일 수정:
```bash
algo-config edit
# GIT_DEFAULT_BRANCH="master" (또는 본인의 브랜치명)
```

### IDE가 자동으로 열리지 않을 때

**1. IDE 감지 확인**
```bash
check_ide
```

**2. IDE 우선순위 변경**
```bash
algo-config edit
# IDE_PRIORITY="pycharm code idea"  (원하는 순서로)
```

**3. IDE 실행 파일 확인**
```bash
# VSCode
which code

# PyCharm (Windows Git Bash)
which pycharm64.exe

# macOS/Linux
which pycharm
```

### 파일이 생성되지 않을 때

**1. 경로 확인**
```bash
algo-config show  # ALGO_BASE_DIR 확인
```

**2. 디렉토리 생성 권한 확인**
```bash
ls -la ~/Desktop  # Desktop 폴더 권한 확인
```

**3. 경로 수정**
```bash
algo-config edit
# ALGO_BASE_DIR="$HOME/Desktop/Algorithm-Practics"
```

---

## 📝 파일 위치 요약

| 파일/디렉토리 | 위치 | 설명 |
|--------------|------|------|
| 셸 함수 정의 | `~/.bashrc` | algo_functions.sh 내용이 추가됨 |
| 설정 파일 | `~/.algo_config` | 사용자 설정 (자동 생성) |
| 작업 디렉토리 | `~/Desktop/Algorithm-Practics/` | 문제 풀이 파일들 |
| Git 저장소 | `~/Desktop/Algorithm-Practics/.git` | Git 정보 |

**경로 표시 규칙:**
- `~` = 홈 디렉토리 (`/home/사용자명` 또는 `/c/Users/사용자명`)
- `~/Desktop` = 바탕화면
- `~/.bashrc` = 홈 디렉토리의 숨김 파일

---

## 🔍 자주 사용하는 명령어 모음

```bash
# 새 문제 시작
al s 1234

# 깃랩 문제 풀이 시작
gitup "주소"

# 깃랩 문제 풀이 완료
gitdown

# 설정 보기
algo-config show

# 설정 변경
algo-config edit

# IDE 확인
check_ide

# Git 상태 확인
git status

# 현재 위치 확인
pwd

# 홈으로 이동
cd ~

# 작업 디렉토리로 이동
cd ~/Desktop/Algorithm-Practics
```

---

## 기여 (Contribution)

이 저장소는 개인적인 학습 및 연습을 위한 공간입니다. 
피드백 및 개선 제안은 언제나 환영합니다!

---

**Made with ❤️ for efficient algorithm problem solving**