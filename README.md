# 알고리즘/실습 자동화 Shell 함수 (V8.1.3)

이 저장소는 Bash 함수들을 제공하여 알고리즘 풀이와 SSAFY 실습 과제 제출을 자동화합니다.
별도의 복잡한 설치 없이 스크립트 파일만 복사하여 즉시 사용할 수 있습니다.

---

## 🛠 1. 설치 및 적용

### 🚀 빠른 설치 (Quick Start)

복잡한 명령어 입력이나 설정을 건너뛰고 싶으신가요?  
아래 버튼을 눌러 **[설치 포털]**로 이동하면 **클릭 두 번**으로 모든 준비가 끝납니다!

<br>

<div align="center">
  <h3>✨ 누구나 쉽게 시작하기</h3>
  <a href="https://junDevCodes.github.io/SSAFY_sh_func/">
    <img src="https://img.shields.io/badge/🚀_설치_및_설정_마법사_실행-Click_Here_to_Start-3b82f6?style=for-the-badge&logo=rocket&logoColor=white" height="60">
  </a>
  <p>👆 위 버튼을 클릭하면 <b>설치 포털</b>로 이동합니다.</p>
</div>

<br>

> **수동 설치를 원하시나요?**  
> 터미널에서 아래 명령어를 실행하세요:
> ```bash
> bash <(curl -fsSL https://raw.githubusercontent.com/junDevCodes/SSAFY_sh_func/main/install.sh)
> ```

설치가 끝나면 `source ~/.bashrc`를 실행하거나 터미널을 다시 열어주세요.

### 방법 2: 수동 설치
```bash
# 1. 저장소 복제
git clone https://github.com/junDevCodes/SSAFY_sh_func.git ~/.ssafy-tools

# 2. 셸 설정 파일에 추가
echo 'source ~/.ssafy-tools/algo_functions.sh' >> ~/.bashrc
source ~/.bashrc
```

---

## 🔐 2. 보안 안내 (Security Notice)

**[중요] V7.7부터 SSAFY LMS 토큰을 파일에 저장하지 않습니다.**

이 도구는 **세션 전용(Session-Only)** 방식으로 토큰을 관리하여 보안성을 극대화합니다:
- ✅ 토큰은 **현재 터미널 세션에서만 유효**합니다.
- ✅ 터미널 종료 시 **자동으로 삭제**됩니다.
- ✅ `~/.algo_config` 파일에 저장되지 않으므로 유출 위험이 없습니다.

`gitup` 등 토큰이 필요한 명령어 실행 시 자동으로 입력을 요청하며, 한 번 입력하면 세션이 유지되는 동안 재입력할 필요가 없습니다. (토큰 유효기간: 24시간)

---

## 🔄 3. 업데이트

새로운 기능이 추가되면 아래 명령어로 간단히 업데이트할 수 있습니다.
```bash
algo-update
```


---

## 🔑 3. 토큰 설정 (SSAFY 전용)

`gitup`의 **실습실 일괄 자동 생성** 기능을 사용하려면 본인의 SSAFY 계정 권한(Token)이 필요합니다. 토큰은 약 24시간 동안 유효하며, 만료 시 스크립트가 자동으로 감지하여 재입력을 요청합니다.

### 1. 북마크릿(Bookmarklet) 이용하기 (강력 권장) ⭐
복잡한 개발자 도구(F12) 없이, 클릭 한 번으로 **URL과 토큰을 동시에 복사**합니다.

1.  브라우저 북마크바에 새 북마크를 만듭니다. (이름: `SSAFY Smart Copy`)
2.  URL 입력란에 아래 코드를 그대로 붙여넣습니다.
    ```javascript
    javascript:(function(){var t="";var r=/(eyJ[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+)/;function s(o){for(var i=0;i<o.length;i++){var k=o.key(i);var v=o.getItem(k);if(!v)continue;if(v.startsWith("Bearer ")){return v;}var m=v.match(r);if(m){return"Bearer "+m[1];}}return"";}t=s(localStorage)||s(sessionStorage);if(!t){alert("❌ 인증 토큰을 찾을 수 없습니다.\n\n로그인 상태를 확인하세요.");return;}try{var e=btoa(t);var res=window.location.href+"|"+e;navigator.clipboard.writeText(res).then(function(){alert("✅ 복사 완료!\n\ngitup을 인자 없이 실행하고 붙여넣으세요.");},function(){prompt("Ctrl+C로 복사:",res);});}catch(x){alert("오류: "+x.message);}})();
    ```
3.  SSAFY 실습실 페이지에서 북마크를 클릭합니다.
4.  "복사 완료!" 알림이 뜨면 터미널에서 `gitup`을 **인자 없이** 실행합니다.
5.  **Secure Input 모드**가 뜨면 `Ctrl+V` (붙여넣기) 후 엔터를 칩니다. (화면에 보이지 않아 안전합니다!)

### 2. 토큰 수동 설정
- `gitup <URL>` 실행 시 토큰이 필요하면 입력창이 뜹니다.
- 토큰은 **파일에 저장되지 않으며**, 현재 터미널 세션에서만 유지됩니다.
- **[V7.7 Security]**: 세션 메타데이터(`.ssafy_session_meta`)에도 암호화가 적용되어 개인정보를 보호합니다.

---

## ⚙️ 4. 설정 파일

모든 사용자 설정은 `~/.algo_config`에 저장됩니다.

- **명령어:**
  - `algo-config show`: 현재 설정값 확인 (**Clean UI**)
  - `algo-config edit`: **설정 마법사(GUI)** 실행
  - `algo-config reset`: 설정을 초기 상태로 되돌리기
  - `algo-doctor`: **(New)** 시스템 및 설정 상태 정밀 진단

- **주요 설정항목:**
  - `ALGO_BASE_DIR`: 알고리즘 문제 저장 경로
  - `GIT_COMMIT_PREFIX`: 커밋 메시지 접두사 (기본값: `solve`)
  - `GIT_DEFAULT_BRANCH`: 기본 푸시 브랜치 (기본값: `main`)
  - `GIT_AUTO_PUSH`: `gitdown` 시 자동 push 여부
  - `IDE_EDITOR`: 사용할 IDE 자동 감지 및 설정 (`code`, `pycharm`, `idea`, `cursor` 등)
  - `SSAFY_USER_ID`: SSAFY GitLab 사용자명 (lab.ssafy.com/{여기} 부분)

> 💡 **[V7.5.2]** `algo-config edit` 메뉴 5번에서 Git 설정(커밋 접두사, 기본 브랜치, 자동 푸시)을 변경할 수 있습니다.

---

## 🚀 주요 기능 요약

### [gitup] 실습실 일괄 생성 및 클론
#### 1. 보안 모드 (권장 🔐)
- **사용법:** `gitup` (인자 없이 엔터)
- **설명:** 화면에 입력 내용이 보이지 않는 **Secure Input** 모드입니다.
- **활용:** 북마크릿으로 복사한 `URL|Token`을 붙여넣을 때 안전합니다.

#### 2. 일반 모드 (빠른 실행 ⚡)
- **사용법:** `gitup <URL>` 또는 `gitup <주제명>`
- **설명:** 단순 `git clone`이나 이미 토큰이 설정된 상태에서 URL만 빠르게 입력할 때 유용합니다.

- **기능:** 실습실 링크를 넣으면 **1번~7번 문제 자동 생성 + 전체 클론 + 1번 IDE 열기**를 한 번에 수행합니다.
- **자동 정렬:** 생성 시간을 기준으로 `ws` -> `hw` 순서로 정확하게 정렬합니다.

### [gitdown] 과제 제출 및 다음 문제 이동
- **사용법:**
  - `gitdown`: 현재 폴더 제출 및 다음 문제 이동
  - `gitdown --all`: **(New)** 세션 내 모든 실습실 일괄 제출
- **스마트 기능:**
  - **제출 바로가기:** 제출 완료 시 SSAFY 실습실 페이지 URL을 제공하며 브라우저 열기 옵션 지원
  - **동적 Playlist:** 아직 풀지 않은 문제가 있으면 감지하여 해당 문제로 이동 제안
  - **자동화:** `add` + `commit` + `push` 및 `gitdown --all` 시 성공/실패 결과 요약
  - **Auto-Sync:** 이미 푼 문제의 완료 상태를 자동으로 동기화하여 중복 이동 방지

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