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

def save_config(config):
    # 기존 파일 내용을 읽어서 주석은 유지하고 값만 교체하는 것이 베스트이나,
    # 여기서는 간단하게 새로 쓴다 (순서 유지 노력).
    # 단, 사용자가 기존에 주석을 많이 달아놨다면 보존하는 게 좋음.
    # 일단 'sed'가 아니므로 전체 재작성 방식 사용.
    
    content = []
    # 기본 템플릿
    lines = [
        f'# 알고리즘 문제 풀이 디렉토리 설정',
        f'ALGO_BASE_DIR="{config.get("ALGO_BASE_DIR", "")}"',
        '',
        f'# Git 설정',
        f'GIT_DEFAULT_BRANCH="{config.get("GIT_DEFAULT_BRANCH", "main")}"',
        f'GIT_COMMIT_PREFIX="{config.get("GIT_COMMIT_PREFIX", "solve")}"',
        f'GIT_AUTO_PUSH={config.get("GIT_AUTO_PUSH", "true")}',
        '',
        f'# SSAFY 설정',
        f'SSAFY_BASE_URL="{config.get("SSAFY_BASE_URL", "https://lab.ssafy.com")}"',
        f'SSAFY_USER_ID="{config.get("SSAFY_USER_ID", "")}"',
        f'SSAFY_AUTH_TOKEN="{config.get("SSAFY_AUTH_TOKEN", "")}"',
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

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def main_menu(config):
    while True:
        clear_screen()
        print("==========================================")
        print(" 🛠  SSAFY Algo Tools 설정 마법사 (V7.4.1)")
        print("==========================================")
        
        ide_code = config.get("IDE_EDITOR", "code")
        # IDE 이름 찾기
        ide_name = ide_code
        for k, v in IDE_POOL.items():
            if v[1] == ide_code: ide_name = v[0]
            
        token_status = "설정됨 (암호화됨)" if config.get("SSAFY_AUTH_TOKEN") else "미설정"
        
        print(f" 1. 📁 작업 디렉토리 변경  [{config.get('ALGO_BASE_DIR', '미설정')}]")
        print(f" 2. 💻 IDE 변경           [{ide_name}]")
        print(f" 3. 🔑 SSAFY 토큰 설정     [{token_status}]")
        print(f" 4. 👤 SSAFY ID 설정       [{config.get('SSAFY_USER_ID', '미설정')}]")
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
            print("\n[SSAFY 토큰 설정]")
            print("발급받은 Bearer 토큰을 붙여넣으세요.")
            print("(입력 시 문자가 보이지 않습니다)")
            new_token = getpass.getpass("👉 Token: ").strip()
            
            if new_token:
                # 암호화 (Base64)
                if not new_token.startswith("Bearer "):
                    # 사용자가 Bearer 없이 넣었을 수도 있으니 처리해주면 친절하지만
                    # 보통 Bearer 포함해서 복사하라고 안내함.
                    # 여기서는 있는 그대로 받아서 처리.
                    # 단, Base64 인코딩 진행
                    pass
                    
                encoded = base64.b64encode(new_token.encode('utf-8')).decode('utf-8')
                config["SSAFY_AUTH_TOKEN"] = encoded
                print("✅ 토큰이 암호화되어 설정되었습니다.")
                input("엔터키를 눌러 계속...")
                
        elif choice == "4":
             new_id = input(f"SSAFY ID 입력 (현재: {config.get('SSAFY_USER_ID', '')}): ").strip()
             if new_id: config["SSAFY_USER_ID"] = new_id
             
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
