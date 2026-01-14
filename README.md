# 알고리즘/실습 자동화 Shell 함수 (V5)

이 저장소는 Bash 함수들을 제공하여 알고리즘 풀이와 SSAFY 실습 과제 제출을 자동화합니다.
별도의 복잡한 설치 없이 스크립트 파일만 복사하여 즉시 사용할 수 있습니다.

---

## 🛠 1. 설치 및 적용

이 스크립트는 **파일 복사** 방식으로 사용하는 것을 권장합니다.

### 1) 파일 위치 결정
```bash
mkdir -p ~/scripts
# 아래 두 파일을 같은 폴더에 복사하세요.
cp ./algo_functions.sh ./ssafy_batch_create.py ~/scripts/
```

### 2) 셸 설정 파일에 적용
사용 중인 셸 설정 파일(`~/.bashrc` 또는 `~/.zshrc`) 끝에 아래 내용을 추가합니다.
```bash
echo 'source ~/scripts/algo_functions.sh' >> ~/.bashrc
source ~/.bashrc
```

---

## 🔄 2. 업데이트

새로운 기능이 추가되었을 때 기존 파일을 덮어쓰기만 하면 됩니다.
```bash
cp ./algo_functions.sh ./ssafy_batch_create.py ~/scripts/
source ~/.bashrc
```

---

## 🔑 3. 토큰 설정 (SSAFY 전용)

`gitup`의 **실습실 일괄 자동 생성** 기능을 사용하려면 본인의 SSAFY 계정 권한(Token)이 필요합니다. 토큰은 약 24시간 동안 유효하며, 만료 시 스크립트가 자동으로 감지하여 재입력을 요청합니다.

### 북마크릿(Bookmarklet) 이용하기 (권장)
복잡한 개발자 도구(F12) 없이 클릭 한 번으로 토큰을 가져올 수 있습니다.

1.  브라우저 북마크바에 새 북마크를 만듭니다.
2.  이름: `SSAFY 토큰 복사`
3.  URL: 아래 코드를 그대로 복사해서 넣습니다.
    ```javascript
    javascript:(function(){var t=localStorage.getItem('accessToken');if(!t)alert('SSAFY 로그인 후 클릭하세요!');else prompt('Ctrl+C로 복사:','Bearer '+t);})();
    ```
    [![token_setting.png](https://i.postimg.cc/qR7Nr7NK/image.png)](https://postimg.cc/zL9zS8SD)
4.  실습실 주소(`project.ssafy.com`)에 로그인된 상태로 북마크를 클릭하면 토큰이 팝업으로 뜹니다. `Ctrl+C`로 복사하세요.
    [![token_copy.png](https://i.postimg.cc/tT73XbJk/image-1.png)](https://postimg.cc/1nhnHLpV)

### 토큰 입력 및 저장
- `gitup` 실행 시 토큰이 없거나 만료되었다면 입력창이 뜹니다.
- 복사한 토큰(`Bearer eyJ...`)을 붙여넣으면 `~/.algo_config`에 자동으로 저장되어 다음부터는 묻지 않습니다.

---

## ⚙️ 4. 설정 파일

모든 사용자 설정은 `~/.algo_config`에 저장됩니다.

- **명령어:**
  - `algo-config show`: 현재 설정값 확인
  - `algo-config edit`: 설정 파일 편집 (기본 에디터)
  - `algo-config reset`: 설정을 초기 상태로 되돌리기

- **주요 설정항목:**
  - `ALGO_BASE_DIR`: 알고리즘 문제 저장 경로
  - `GIT_AUTO_PUSH`: `gitdown` 시 자동 push 여부
  - `IDE_PRIORITY`: 추천 IDE 우선순위 (`code`, `pycharm` 등)
  - `SSAFY_USER_ID`: 본인의 SSAFY 학번/ID

---

## 🚀 주요 기능 요약

### [gitup] 실습실 일괄 생성 및 클론
- **사용법:** `gitup <실습실URL | 주제명>`
- **스마트 배치:** 실습실 링크를 넣으면 **1번~7번 문제 자동 생성 + 전체 클론 + 1번 IDE 열기**를 한 번에 수행합니다.
- **자동 정렬:** 생성 시간을 기준으로 `ws` -> `hw` 순서로 정확하게 정렬합니다.

### [gitdown] 과제 제출 및 다음 문제 이동
- **사용법:** `gitdown [커밋메시지] [--ssafy]`
- **자동화:** `add` + `commit` + `push`를 한 번에 처리합니다.
- **워크플로우:** `--ssafy` 옵션 사용 시, 제출 성공과 동시에 다음 순서의 문제 폴더로 자동 이동하고 IDE를 엽니다.

### [al] 알고리즘 문제 풀이 보조
- **사용법:** `al <site> <number> [py|cpp]`
- **구조화:** 폴더 생성, 기본 코드 파일 생성, 샘플 입력 파일 생성, IDE 자동 실행까지 처리합니다.
- **대상 사이트:** BOJ(b), SWEA(s), Programmers(p) 등

---

## 🧪 테스트 실행
```bash
# Windows PowerShell 환경인 경우
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1

# Python 직접 실행 (결과 JSON 저장)
python tests/run_tests.py --out tests/test_results.json
```

test_noti