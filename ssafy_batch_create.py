import sys
import requests
import re
import time
import urllib.parse

# ==================================================================================
# [사용자 설정 영역]
# 브라우저 F12 > Network 탭에서 가져온 헤더 값을 아래에 넣어주세요.
# ==================================================================================
HEADERS = {
    "accept": "application/json, text/plain, */*",
    "authorization": "Bearer eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiI4YTgxOTQ4OTk3ZTU3NjAxMDE5ODA2YTg5M2U2MDI2MiIsImlhdCI6MTc2ODI3MzgwNSwiZXhwIjoxNzY4MzYwMjA1fQ.FwVXPaHSxRbsxEi2tn-tkmtrncbExJOBgWT3COOPbgEkGw4bg56mCUmvVLy01cYJj2bKlM5zsZ60SB5wnFFrQA",
    "cookie": "SCOUTER=z57ch88if8g7a9",
    "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36"
}
# ==================================================================================

def parse_url(url):
    """URL에서 Course, Practice, Answer ID를 추출합니다."""
    # 예: .../course/CS.../practice/PR.../answer/PA...
    course_match = re.search(r'course/(CS\d+)', url)
    practice_match = re.search(r'practice/(PR\d+)', url)
    answer_match = re.search(r'answer/(PA\d+)', url)
    
    c_id = course_match.group(1) if course_match else None
    p_id = practice_match.group(1) if practice_match else None
    a_id = answer_match.group(1) if answer_match else None
    
    return c_id, p_id, a_id

def detect_index_from_repo(repo_url):
    """레포 URL에서 문제 번호(순서)를 추출합니다. (예: ws_3_2 -> 2)"""
    if not repo_url:
        return None
    
    # 예: https://.../ds_ws_3_2 또는 .../algo_hw_1_2
    # 마지막 숫자를 추출
    match = re.search(r'_(\d+)$', repo_url)
    if match:
        return int(match.group(1))
    return None

def batch_create(start_url, count):
    course_id, start_pr, answer_id = parse_url(start_url)
    
    if not course_id or not start_pr:
        print("❌ URL 형식이 올바르지 않습니다.")
        return
    
    print(f"🚀 [SSAFY Smart Creator] 분석 시작: {start_pr}")
    
    # 기본값: 안전하게 -2부터 시작 (만약 분석 실패 시)
    start_offset = -2
    
    # 1. Answer ID로 상세 정보 조회 -> 내 위치(인덱스) 파악
    is_smart_mode = False
    
    if answer_id:
        info_url = f"https://project.ssafy.com/ssafy/api/courses/{course_id}/practices/{start_pr}/answers/{answer_id}"
        try:
            # GET 요청으로 레포 정보를 확인
            res = requests.get(info_url, headers=HEADERS)
            if res.status_code == 200:
                data = res.json()
                repo = data.get('repositoryUrl', '')
                
                # 레포 주소가 있으면 Index 유추
                idx = detect_index_from_repo(repo)
                if idx:
                    # 예: 2번 문제면(idx=2) -> 시작점은 -1 (2-1=1번)
                    # 예: 1번 문제면(idx=1) -> 시작점은 0
                    start_offset = -(idx - 1)
                    print(f"💡 감지됨: {repo} (No.{idx})")
                    print(f"👉 1번 문제({start_offset}칸 전)부터 스캔합니다.")
                    is_smart_mode = True
                else:
                    print("⚠️ 레포 정보가 없거나 분석 불가. 기본값(-2) 사용.")
            else:
                 print(f"⚠️ 상세 조회 실패({res.status_code}). 기본값(-2) 사용.")
        except Exception as e:
            print(f"⚠️ 네트워크 에러: {e}")
    else:
        print("⚠️ Answer ID가 URL에 없습니다. 기본값(-2) 사용.")

    # PR 번호 계산
    try:
        start_num = int(start_pr.replace("PR", ""))
    except:
        return

    # 2. 루프 실행
    # Smart Mode면 1번부터 시작하도록 offset 설정됨
    # Count만큼 뒤로 검색
    
    end_offset = start_offset + count - 1 # 총 count개
    
    print("-" * 60)
    
    for i in range(start_offset, end_offset + 1):
        curr_num = start_num + i
        pr_id = f"PR{str(curr_num).zfill(8)}" 
        
        # UI 라벨링
        if i == 0: label = "[기준]" 
        elif i == start_offset: label = "[시작]"
        else: label = f"[{i:+d}]"
        
        create_url = f"https://project.ssafy.com/ssafy/api/courses/{course_id}/practices/{pr_id}/answers"
        
        print(f"👉 {label} {pr_id} 생성...", end=" ")
        
        try:
            res = requests.post(create_url, headers=HEADERS, json={})
            status = res.status_code
            
            if status == 200:
                repo = res.json().get('repositoryUrl')
                print(f"✅ 완료: {repo}")
            elif status == 405: 
                 print(f"ℹ️ 이미 존재")
            elif status == 404:
                 print(f"❌ 없음")
            elif status == 403:
                 print(f"🚫 권한 없음")
            else:
                print(f"⚠️ Error {status}")
        except:
            print("Err")
            
        time.sleep(0.3)

    print("-" * 60)
    print(f"🏁 작업 완료.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python ssafy_batch_create.py <URL> [COUNT]")
        sys.exit(1)
        
    url = sys.argv[1]
    cnt = 7 
    if len(sys.argv) > 2:
        try: cnt = int(sys.argv[2])
        except: pass
            
    batch_create(url, cnt)
