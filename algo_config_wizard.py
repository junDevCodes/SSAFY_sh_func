#!/usr/bin/env python3
import os
import sys
import base64
import getpass
import re

CONFIG_FILE = os.path.expanduser("~/.algo_config")
IDE_POOL = {
    "1": ("VS Code", "code"),
    "2": ("Cursor", "cursor"),
    "3": ("PyCharm", "pycharm"),
    "4": ("IntelliJ IDEA", "idea"),
    "5": ("Sublime Text", "subl"),
    "6": ("Antigravity", "antigravity")
}

def sanitize_config_value(value, allow_empty=False):
    """설정 파일에 안전하게 저장할 수 있는 값으로 검증
    
    Returns:
        (str, None): 검증된 값
        (None, str): 오류 메시지
    """
    if not value or not value.strip():
        if allow_empty:
            return "", None
        return None, "빈 값은 사용할 수 없습니다"
    
    value = value.strip()
    
    # 금지 문자 검사
    forbidden_chars = ['"', "'", '$', '`', '\\', '\n', '\r', ';', '|', '&']
    for char in forbidden_chars:
        if char in value:
            char_display = repr(char).strip("'")
            return None, f"특수문자 '{char_display}'는 사용할 수 없습니다"
    
    return value, None

def load_config():
    config = {}
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            for line in f:
                if "=" in line and not line.strip().startswith("#"):
                    key, val = line.split("=", 1)
                    val = val.strip().strip('"').strip("'")
                    config[key.strip()] = val
    return config

import time

# [V7.6] Cross-platform File Lock
class FileLock:
    def __init__(self, file_path):
        self.lock_file = file_path + ".lock"
        
    def acquire(self, timeout=3):
        start = time.time()
        while time.time() - start < timeout:
            try:
                # O_CREAT | O_EXCL ensures atomic creation
                fd = os.open(self.lock_file, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                os.close(fd)
                return True
            except OSError:
                time.sleep(0.1)
        return False

    def release(self):
        try:
            os.remove(self.lock_file)
        except OSError:
            pass

def save_config(config):
    # Lock 획득 시도
    lock = FileLock(CONFIG_FILE)
    if not lock.acquire():
        print("⚠️  설정 파일이 다른 프로세스에서 사용 중입니다. 잠시 후 다시 시도하세요.")
        return

    try:
        lines = [
            '# SSAFY Algo Tools Config (UTF-8)',
            '',
            '# 알고리즘 문제 풀이 디렉토리',
            f'ALGO_BASE_DIR="{config.get("ALGO_BASE_DIR", "")}"',
            '',
            '# Git 설정',
            f'GIT_DEFAULT_BRANCH="{config.get("GIT_DEFAULT_BRANCH", "main")}"',
            f'GIT_COMMIT_PREFIX="{config.get("GIT_COMMIT_PREFIX", "solve")}"',
            f'GIT_AUTO_PUSH="{config.get("GIT_AUTO_PUSH", "true")}"',
            '',
            '# SSAFY 설정',
            f'SSAFY_BASE_URL="{config.get("SSAFY_BASE_URL", "https://lab.ssafy.com")}"',
            f'SSAFY_USER_ID="{config.get("SSAFY_USER_ID", "")}"',
            # [Security] 토큰은 파일에 저장하지 않음 (세션 전용)
            '',
            '# IDE 설정',
            f'IDE_EDITOR="{config.get("IDE_EDITOR", "code")}"',
            '',
            '# 업데이트 및 UI 설정',
            f'SSAFY_UPDATE_CHANNEL="{config.get("SSAFY_UPDATE_CHANNEL", "stable")}"',
            f'ALGO_UI_STYLE="{config.get("ALGO_UI_STYLE", "panel")}"',
            f'ALGO_UI_COLOR="{config.get("ALGO_UI_COLOR", "auto")}"',
            f'ALGO_INPUT_PROFILE="{config.get("ALGO_INPUT_PROFILE", "stable")}"',
            ''
        ]

        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))

        # 권한 설정 (600)
        try:
            os.chmod(CONFIG_FILE, 0o600)
        except Exception:
            pass

    finally:
        lock.release()

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def get_version():
    try:
        version_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "VERSION")
        if os.path.exists(version_file):
            with open(version_file, "r", encoding="utf-8") as f:
                return f.read().strip()
    except:
        pass
    return "Unknown"

def pick_folder_gui(initial_dir=None):
    """Open a folder selection dialog using tkinter."""
    try:
        import tkinter as tk
        from tkinter import filedialog
        
        # Create root window but hide it
        root = tk.Tk()
        root.withdraw()
        
        # Bring dialog to front
        root.attributes('-topmost', True)
        
        selected_path = filedialog.askdirectory(
            initialdir=initial_dir,
            title="SSAFY 작업 경로 선택 (취소하면 직접 입력)"
        )
        
        root.destroy()
        
        # tkinter returns empty string on cancel
        if not selected_path:
            return None
            
        # Convert to absolute path with forward slashes
        return os.path.abspath(selected_path).replace("\\", "/")
    except Exception as e:
        # print(f"GUI Error: {e}") 
        return None

def first_run_setup(config, is_first_run=False):
    """첫 실행이거나 필수 설정이 비어있을 때 자동으로 필수 항목 입력을 받는다.
    
    조건:
      - is_first_run=True (설정 파일이 없었던 경우)
      - ALGO_BASE_DIR 이 비어있거나 기본값($HOME/algos)인 경우
      - SSAFY_USER_ID 가 비어있는 경우
    """
    home = os.path.expanduser("~").replace("\\", "/")
    default_algo_dir = home + "/algos"

    current_algo_dir = config.get("ALGO_BASE_DIR", "").replace("\\", "/").rstrip("/")
    current_user_id  = config.get("SSAFY_USER_ID", "")

    needs_algo_dir  = not current_algo_dir or current_algo_dir == default_algo_dir
    needs_user_id   = not current_user_id

    if not is_first_run and not needs_algo_dir and not needs_user_id:
        return config

    clear_screen()
    version = get_version()
    print("==========================================")
    if is_first_run:
        print(f" ✨ 첫 설치를 환영합니다! ({version})")
    else:
        print(f" ⚠️  필수 설정이 비어있습니다. ({version})")
    print(" 아래 항목을 설정해야 도구를 정상적으로 사용할 수 있습니다.")
    print("==========================================")
    print()

    # ── ALGO_BASE_DIR ──────────────────────────────────────
    if needs_algo_dir:
        print("📁 [필수] 알고리즘 문제 풀이 파일을 저장할 경로를 설정합니다.")
        print(f"   기본 경로: {default_algo_dir}")
        print()
        print("   📂 폴더 선택 창을 띄웁니다... (작업표시줄을 확인하세요)")
        gui_path = pick_folder_gui(home)
        if gui_path:
            validated, error = sanitize_config_value(gui_path)
            if not error:
                config["ALGO_BASE_DIR"] = validated
                print(f"   ✅ 경로 설정됨: {validated}")
            else:
                print(f"   ⚠️ 경로 오류: {error}")
                gui_path = None
        if not gui_path:
            print("   ⚠️ GUI 선택이 취소되었거나 실패했습니다.")
            print(f"   직접 경로를 입력해주세요. (예: {default_algo_dir})")
            while True:
                new_dir = input("   경로 입력: ").strip()
                if not new_dir:
                    print("   ⚠️ 경로를 입력해주세요. 빈 값은 허용되지 않습니다.")
                    continue
                validated, error = sanitize_config_value(new_dir)
                if error:
                    print(f"   ⚠️ {error}")
                else:
                    config["ALGO_BASE_DIR"] = validated
                    print(f"   ✅ 경로 설정됨: {validated}")
                    break
        print()

    # ── SSAFY_USER_ID ──────────────────────────────────────
    if needs_user_id:
        print("👤 [필수] SSAFY GitLab 사용자 ID를 입력합니다.")
        print("   (lab.ssafy.com 접속 후 주소창: https://lab.ssafy.com/{여기가 ID})")
        while True:
            uid = input("   SSAFY ID 입력: ").strip()
            validated, error = sanitize_config_value(uid)
            if error:
                print(f"   ⚠️ {error}")
            elif not validated:
                print("   ⚠️ ID는 반드시 입력해야 합니다.")
            else:
                config["SSAFY_USER_ID"] = validated
                print(f"   ✅ SSAFY ID 설정됨: {validated}")
                break
        print()

    # ── IDE 선택 (선택, 첫 실행 시에만) ────────────────────
    if is_first_run:
        print("💻 [선택] 사용할 IDE를 선택합니다.")
        for k, v in IDE_POOL.items():
            print(f"   {k}. {v[0]} ({v[1]})")
        current_ide = config.get("IDE_EDITOR", "code")
        ide_choice = input(f"   번호 선택 (Enter 시 현재값 '{current_ide}' 유지): ").strip()
        if ide_choice in IDE_POOL:
            config["IDE_EDITOR"] = IDE_POOL[ide_choice][1]
            print(f"   ✅ IDE 설정됨: {IDE_POOL[ide_choice][0]}")
        else:
            print(f"   ✅ IDE 유지: {current_ide}")
        print()

        # ── Git 기본 설정 (선택, 첫 실행 시에만) ─────────────
        print("🔀 [선택] Git 기본 설정을 합니다. (Enter 시 아래 괄호 기본값 사용)")
        print()

        # 기본 브랜치
        cur_branch = config.get("GIT_DEFAULT_BRANCH", "main")
        user_branch = input(f"   기본 브랜치 (현재: {cur_branch}): ").strip()
        if user_branch:
            validated, error = sanitize_config_value(user_branch)
            if not error and validated:
                config["GIT_DEFAULT_BRANCH"] = validated
                print(f"   ✅ 기본 브랜치: {validated}")
            else:
                print(f"   ✅ 기본 브랜치 유지: {cur_branch}")
        else:
            print(f"   ✅ 기본 브랜치 유지: {cur_branch}")

        # 커밋 접두사
        cur_prefix = config.get("GIT_COMMIT_PREFIX", "solve")
        user_prefix = input(f"   커밋 접두사 (현재: {cur_prefix}): ").strip()
        if user_prefix:
            validated, error = sanitize_config_value(user_prefix)
            if not error and validated:
                config["GIT_COMMIT_PREFIX"] = validated
                print(f"   ✅ 커밋 접두사: {validated}")
            else:
                print(f"   ✅ 커밋 접두사 유지: {cur_prefix}")
        else:
            print(f"   ✅ 커밋 접두사 유지: {cur_prefix}")

        # 자동 푸시
        cur_push = config.get("GIT_AUTO_PUSH", "true").lower()
        push_label = "Y" if cur_push == "true" else "N"
        user_push = input(f"   자동 푸시 (현재: {push_label}) [Y/n]: ").strip().lower()
        if user_push in ("n", "no"):
            config["GIT_AUTO_PUSH"] = "false"
            print("   ✅ 자동 푸시: OFF")
        elif user_push in ("y", "yes", ""):
            config["GIT_AUTO_PUSH"] = "true"
            print("   ✅ 자동 푸시: ON")
        else:
            print(f"   ✅ 자동 푸시 유지: {push_label}")
        print()

    print("------------------------------------------")
    print(" 초기 설정 완료! 추가 설정은 아래 메뉴에서 할 수 있습니다.")
    print("------------------------------------------")
    input(" 엔터키를 눌러 메인 메뉴로 이동...")
    return config



def main_menu(config):
    version = get_version()
    while True:
        clear_screen()
        print("==========================================")
        print(f" 🛠  SSAFY Algo Tools 설정 마법사 ({version})")
        print("==========================================")
        
        ide_code = config.get("IDE_EDITOR", "code")
        # IDE 이름 찾기
        ide_name = ide_code
        for k, v in IDE_POOL.items():
            if v[1] == ide_code: ide_name = v[0]
        
        # 메뉴 번호 수정 (Phase 0 Task 0-3)
        print(f" 1. 📁 작업 경로 변경      [{config.get('ALGO_BASE_DIR', '미설정')}]")
        print(f" 2. 💻 IDE 변경           [{ide_name}]")
        print(f" 3. 🔑 SSAFY 토큰 설정     [세션 전용]")
        print(f" 4. 👤 SSAFY ID 설정       [{config.get('SSAFY_USER_ID', '미설정')}]")
        print(f" 5. 🔀 Git 설정")
        print(f"     - 커밋 접두사: {config.get('GIT_COMMIT_PREFIX', 'solve')}")
        print(f"     - 기본 브랜치: {config.get('GIT_DEFAULT_BRANCH', 'main')}")
        print(f"     - 자동 푸시: {config.get('GIT_AUTO_PUSH', 'true')}")
        print("------------------------------------------")
        print(" 0. 💾 저장 및 종료")
        print(" q. ❌ 취소 (저장 안 함)")
        print("==========================================")
        
        choice = input("👉 선택: ").strip()
        
        if choice == "1":
            current_dir = config.get('ALGO_BASE_DIR', '')
            print("\n📁 폴더 선택 창을 띄웁니다... (작업표시줄을 확인하세요)")
            
            gui_path = pick_folder_gui(current_dir)
            if gui_path:
                validated, error = sanitize_config_value(gui_path)
                if error:
                    print(f"⚠️ {error}")
                else:
                    config["ALGO_BASE_DIR"] = validated
                    print(f"✅ 경로가 변경되었습니다: {validated}")
                input("엔터키를 눌러 계속...")
            else:
                print("⚠️ GUI 선택이 취소되었거나 실패했습니다.")
                new_dir = input(f"새 경로 직접 입력 (현재: {current_dir}): ").strip()
                if new_dir: 
                    validated, error = sanitize_config_value(new_dir)
                    if not error:
                        config["ALGO_BASE_DIR"] = validated
                input("엔터키를 눌러 계속...")
            
        elif choice == "2":
            print("\n[IDE 선택]")
            for k, v in IDE_POOL.items():
                print(f"  {k}. {v[0]} ({v[1]})")
            ide_sel = input("👉 번호 선택: ").strip()
            
            if ide_sel in IDE_POOL:
                config["IDE_EDITOR"] = IDE_POOL[ide_sel][1]
            else:
                input("⚠️ 잘못된 번호입니다. 엔터키를 누르세요.")
                
        elif choice == "3":
            print("\n[🔐 SSAFY 토큰 설정]")
            print("")
            print("  보안상 토큰은 파일에 저장되지 않으며 현재 터미널 세션에서만 유지됩니다.")
            print("  gitup 실행 시 SmartLink(URL|Token) 형식으로 자동 요청됩니다.")
            print("  터미널 종료 시 토큰은 자동으로 삭제됩니다.")
            print("")
            current_token = os.environ.get("SSAFY_AUTH_TOKEN", "")
            if current_token:
                print("  현재 상태: ✅ 세션에 토큰이 설정되어 있습니다.")
            else:
                print("  현재 상태: ❌ 세션에 토큰이 없습니다.")
            print("")
            try:
                token_input = getpass.getpass("  지금 세션에 토큰을 설정하려면 입력하세요 (건너뛰려면 Enter): ").strip()
                if token_input:
                    os.environ["SSAFY_AUTH_TOKEN"] = token_input
                    print("  ✅ 세션에 토큰이 설정되었습니다. (터미널 종료 시 삭제)")
                else:
                    print("  ℹ️  건너뜁니다. gitup 실행 시 입력을 요청합니다.")
            except (EOFError, KeyboardInterrupt):
                print("")
                print("  ℹ️  취소되었습니다.")
            input("엔터키를 눌러 계속...")
                
        elif choice == "4":
             new_id = input(f"SSAFY ID 입력 (현재: {config.get('SSAFY_USER_ID', '')}): ").strip()
             if new_id: config["SSAFY_USER_ID"] = new_id
        
        elif choice == "5":
            print("\n[🔀 Git 설정]")
            print(f"  1. 커밋 접두사 (GIT_COMMIT_PREFIX) [{config.get('GIT_COMMIT_PREFIX', 'solve')}]")
            print(f"  2. 기본 브랜치 (GIT_DEFAULT_BRANCH) [{config.get('GIT_DEFAULT_BRANCH', 'main')}]")
            print(f"  3. 자동 푸시 (GIT_AUTO_PUSH) [{config.get('GIT_AUTO_PUSH', 'true')}]")
            print("  0. 돌아가기")
            
            git_choice = input("👉 선택: ").strip()
            
            if git_choice == "1":
                new_prefix = input(f"새 커밋 접두사 (현재: {config.get('GIT_COMMIT_PREFIX', 'solve')}): ").strip()
                validated, error = sanitize_config_value(new_prefix)
                if error:
                    print(f"⚠️ {error}")
                    input("엔터키를 눌러 계속...")
                elif validated:
                    config["GIT_COMMIT_PREFIX"] = validated
                    print(f"✅ 커밋 접두사가 '{validated}'로 변경되었습니다.")
                    input("엔터키를 눌러 계속...")
            elif git_choice == "2":
                new_branch = input(f"새 기본 브랜치 (현재: {config.get('GIT_DEFAULT_BRANCH', 'main')}): ").strip()
                validated, error = sanitize_config_value(new_branch)
                if error:
                    print(f"⚠️ {error}")
                    input("엔터키를 눌러 계속...")
                elif validated:
                    config["GIT_DEFAULT_BRANCH"] = validated
                    print(f"✅ 기본 브랜치가 '{validated}'로 변경되었습니다.")
                    input("엔터키를 눌러 계속...")
            elif git_choice == "3":
                current_val = str(config.get('GIT_AUTO_PUSH', 'true')).lower()
                new_val = 'false' if current_val == 'true' else 'true'
                config["GIT_AUTO_PUSH"] = new_val
                print(f"✅ 자동 푸시가 '{new_val}'로 변경되었습니다.")
                input("엔터키를 눌러 계속...")
             
        elif choice == "0":
            # 필수 항목 검증
            home = os.path.expanduser("~").replace("\\", "/")
            default_algo_dir = home + "/algos"
            current_algo = config.get("ALGO_BASE_DIR", "").replace("\\", "/").rstrip("/")
            current_uid  = config.get("SSAFY_USER_ID", "").strip()
            missing = []
            if not current_algo or current_algo == default_algo_dir:
                missing.append("1. 📁 작업 경로 (ALGO_BASE_DIR)")
            if not current_uid:
                missing.append("4. 👤 SSAFY ID (SSAFY_USER_ID)")
            if missing:
                print("\n⛔ 저장할 수 없습니다. 다음 필수 항목을 먼저 설정해주세요:")
                for m in missing:
                    print(f"   - {m}")
                input("엔터키를 눌러 계속...")
            else:
                save_config(config)
                print("✅ 설정이 저장되었습니다.")
                break

        elif choice.lower() == "q":
            print("취소되었습니다.")
            break

if __name__ == "__main__":
    is_first_run = not os.path.exists(CONFIG_FILE)
    if is_first_run:
        # 빈 설정으로 파일 생성 (기본값 아님 - wizard가 채움)
        save_config({})

    cfg = load_config()
    cfg = first_run_setup(cfg, is_first_run=is_first_run)
    main_menu(cfg)
