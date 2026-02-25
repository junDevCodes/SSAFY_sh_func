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
            save_config(config)
            print("✅ 설정이 저장되었습니다.")
            break
            
        elif choice.lower() == "q":
            print("취소되었습니다.")
            break

if __name__ == "__main__":
    if not os.path.exists(CONFIG_FILE):
        print(f"설정 파일이 없습니다: {CONFIG_FILE}")
        print("기본 설정을 생성합니다...")
        save_config({})
        
    cfg = load_config()
    main_menu(cfg)
