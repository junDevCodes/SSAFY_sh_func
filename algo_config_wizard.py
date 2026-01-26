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
    "5": ("Sublime Text", "subl")
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

import os  # 상단 import 확인
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
        # 기존 파일 내용을 읽어서 주석은 유지하고 값만 교체하는 것이 베스트이나,
        # 여기서는 간단하게 새로 쓴다 (순서 유지 노력).
        # 단, 사용자가 기존에 주석을 많이 달아놨다면 보존하는 게 좋음.
        # 일단 'sed'가 아니므로 전체 재작성 방식 사용.
        
        lines = [
            f'# 알고리즘 문제 풀이 디렉토리 설정',
            f'ALGO_BASE_DIR="{config.get("ALGO_BASE_DIR", "")}"',
            '',
            f'# Git 설정',
            f'GIT_DEFAULT_BRANCH="{config.get("GIT_DEFAULT_BRANCH", "main")}"',
            f'GIT_COMMIT_PREFIX="{config.get("GIT_COMMIT_PREFIX", "solve")}"',
            f'GIT_AUTO_PUSH="{config.get("GIT_AUTO_PUSH", "true")}"',
            '',
            f'SSAFY_BASE_URL="{config.get("SSAFY_BASE_URL", "https://lab.ssafy.com")}"',
            f'SSAFY_USER_ID="{config.get("SSAFY_USER_ID", "")}"',
            # [Security V7.7] 토큰은 파일에 저장하지 않음 (세션 전용)
            '',
            f'# IDE 설정',
            f'IDE_EDITOR="{config.get("IDE_EDITOR", "code")}"',
            ''
        ]
        
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
        
        # 권한 설정 (600)
        try:
            os.chmod(CONFIG_FILE, 0o600)
        except:
            pass
            
    finally:
        lock.release()

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def main_menu(config):
    while True:
        clear_screen()
        print("==========================================")
        print(" 🛠  SSAFY Algo Tools 설정 마법사 (V7.5.2)")
        print("==========================================")
        
        ide_code = config.get("IDE_EDITOR", "code")
        # IDE 이름 찾기
        ide_name = ide_code
        for k, v in IDE_POOL.items():
            if v[1] == ide_code: ide_name = v[0]
            
        print(f" 2. 💻 IDE 변경           [{ide_name}]")
        print(f" 3. 🔑 SSAFY 토큰 설정     [세션 전용 - 터미널에서 자동 입력]")
        print(f" 4. 👤 SSAFY ID 설정       [{config.get('SSAFY_USER_ID', '미설정')}]")
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
            new_dir = input(f"새 경로 입력 (현재: {config.get('ALGO_BASE_DIR', '')}): ").strip()
            if new_dir: config["ALGO_BASE_DIR"] = new_dir
            
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
            print("\n[🔐 SSAFY 토큰 안내]")
            print("")
            print("  V7.7부터 토큰은 보안상 파일에 저장되지 않습니다.")
            print("")
            print("  • 토큰은 터미널 세션에서만 유지됩니다.")
            print("  • gitup 실행 시 자동으로 입력을 요청합니다.")
            print("  • 터미널 종료 시 토큰은 자동 삭제됩니다.")
            print("")
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
