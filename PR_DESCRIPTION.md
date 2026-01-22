# 📝 Pull Request: V7.3 IDE Automation & Security Update

## #️⃣ Issue Number
close #120
close #121
close #123

## 📝 요약 (Summary)
이번 **V7.3 업데이트**는 사용자의 편의성과 보안을 대폭 강화하는 것을 목표로 합니다.
주요 변경 사항으로는 **IDE 자동 탐색/연결**, **토큰 보안 입력(Secure Mode)**, **설정 마법사(GUI)** 도입이 있습니다.
이제 사용자는 복잡한 PATH 설정이나 토큰 노출 걱정 없이 안전하고 빠르게 실습 환경을 구축할 수 있습니다.

**주요 기능**:
1. **IDE 자동화**: `pycharm`, `cursor` 등 IDE 설치 경로를 자동 스캔하여 연결 (`algo-doctor` 연동)
2. **보안 강화**: `gitup` 시 **Secure Input** 모드 지원 (화면 노출 방지) 및 설정 파일 권한 강화
3. **UX 개선**: 설정 마법사 (`algo_config_wizard.py`) 및 `algo-config show` UI 전면 개편

---

## 🛠️ PR 유형 (Type of Changes)

- [x] ✨ 새로운 기능 추가 (New Feature)
- [x] 🐛 버그 수정 (Bug Fix)
- [x] 🎨 UI/UX 변경 (UI/UX Update)
- [x] 🛠️ 코드 리팩토링 (Code Refactor)
- [x] 📚 문서 수정 (Documentation Update)
- [ ] 🧪 테스트 추가 / 수정 (Testing)
- [ ] 🔧 빌드 설정 변경 (Build/Package Manager)
- [ ] 🚚 파일 및 폴더 구조 변경 (File/Folder Structure)

---

## 📸 스크린샷 (Screenshots)

| **Smart Copy & Secure Input** | **Config Wizard (GUI)** |
|:---:|:---:|
| (토큰 원클릭 복사 -> 히든 입력) | (직관적인 메뉴형 설정) |

| **Auto IDE Discovery** | **Algo-Doctor & Pretty Config** |
|:---:|:---:|
| (IDE 경로 자동 탐색 및 캐싱) | (설정 상태 및 시스템 진단) |

---

## 💬 리뷰 요청 사항 (Notes for Reviewers)
- `_setup_ide_aliases` 함수의 탐색 경로(`Program Files`, `AppData` 등)가 Windows 환경에서 충분한지 확인 부탁드립니다.
- `algo_config_wizard.py` 실행 시 Python 의존성 문제가 없는지(표준 라이브러리만 사용함) 체크 바랍니다.

---

## ✅ PR 체크리스트 (PR Checklist)
- [x] 📖 커밋 메시지가 팀의 컨벤션에 맞게 작성되었습니다.
- [x] 🧪 변경 사항에 대한 테스트를 완료했습니다. (Windows 환경 Git Bash 테스트 완료)
- [x] 🛠️ 빌드와 실행 테스트를 통과했습니다.
- [x] 📚 관련 문서가 최신 상태로 업데이트되었습니다. (README.md, updatenote.md)
- [x] 🤝 리뷰어와 논의한 내용이 반영되었습니다.
