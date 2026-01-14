import sys
import re
import time
import json
import urllib.request
import urllib.error

# [Helper] Requests 모듈 의존성 제거를 위한 간단한 래퍼
class MockResponse:
    def __init__(self, status_code, content):
        self.status_code = status_code
        self.content = content
        self.text = content.decode('utf-8', errors='ignore') if content else ""
    
    def json(self):
        return json.loads(self.text)

def api_request(url, method="GET", data=None, headers=None):
    if headers is None: headers = {}
    
    body = None
    if data is not None:
        body = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'
        
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req) as res:
            return MockResponse(res.getcode(), res.read())
    except urllib.error.HTTPError as e:
        return MockResponse(e.code, e.read())
    except Exception as e:
        # print(f"Network Error: {e}", file=sys.stderr)
        return MockResponse(999, str(e).encode())

# ==================================================================================
# [사용자 설정 영역]
# ==================================================================================
HEADERS = {
    "accept": "application/json, text/plain, */*",
    "authorization": "Bearer eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiI4YTgxOTQ4OTk3ZTU3NjAxMDE5ODA2YTg5M2U2MDI2MiIsImlhdCI6MTc2ODI3MzgwNSwiZXhwIjoxNzY4MzYwMjA1fQ.FwVXPaHSxRbsxEi2tn-tkmtrncbExJOBgWT3COOPbgEkGw4bg56mCUmvVLy01cYJj2bKlM5zsZ60SB5wnFFrQA",
    "cookie": "SCOUTER=z57ch88if8g7a9",
    "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36"
}
# ==================================================================================

def parse_url(url):
    course_match = re.search(r'course/(CS\d+)', url)
    practice_match = re.search(r'practice/(PR\d+)', url)
    answer_match = re.search(r'answer/(PA\d+)', url)
    
    c_id = course_match.group(1) if course_match else None
    p_id = practice_match.group(1) if practice_match else None
    a_id = answer_match.group(1) if answer_match else None
    
    return c_id, p_id, a_id

def detect_round_from_repo(repo_url):
    """레포 URL에서 차시(Round) 번호를 추출합니다. (예: ws_3_2 -> 3, ws_3_a -> 3)"""
    if not repo_url: return None
    # 마지막 앞의 숫자를 추출 (예: ..._3_1 또는 ..._3_a)
    match = re.search(r'_(\d+)_([a-zA-Z0-9]+)$', repo_url)
    if match: return int(match.group(1))
    return None

# 전역 캐시
REPO_CACHE = {}

def get_repo_info(course_id, pr_id):
    """특정 PR ID에 대해 레포 URL과 PA ID를 조회합니다 (Tuple 반환)."""
    
    # 1. 캐시 확인
    if pr_id in REPO_CACHE:
        return REPO_CACHE[pr_id]
        
    # 실습실 생성(POST) 및 목록 조회(GET)에 사용되는 통합 엔드포인트
    api_url = f"https://project.ssafy.com/ssafy/api/courses/{course_id}/practices/{pr_id}/answers"
    max_retries = 3
    
    for attempt in range(max_retries):
        try:
            # 2. POST 시도 (urllib)
            res = api_request(api_url, method="POST", headers=HEADERS, data={})
            status = res.status_code
            
            repo = None
            pa_id = None
            
            # 2.1 JSON 파싱 및 데이터 추출 (Regex Fallback 추가)
            try:
                r_json = res.json()
                repo = r_json.get('repositoryUrl')
                pa_id = r_json.get('id')
            except:
                pass
            
            # Regex Fallback
            if not repo:
                 mp = re.search(r'"repositoryUrl"\s*:\s*"([^"]+)"', res.text)
                 if mp: repo = mp.group(1)
            
            if not pa_id:
                 mp = re.search(r'"id"\s*:\s*"(PA[0-9]+)"', res.text)
                 if mp: pa_id = mp.group(1)
            
            # 2.2 Repo URL이 바로 있으면 성공
            if repo:
                result = (repo, pa_id)
                REPO_CACHE[pr_id] = result
                return result
                
            # 2.3 Repo URL은 없는데 PA ID(답안 ID)가 있으면 -> 상세 조회 시도
            if pa_id:
                # 0.5초 대기 (생성 직후 조회 시 404/동기화 지연 방지)
                time.sleep(0.5)
                
                print(f"⚠️ [Info] {pr_id}: Found ID {pa_id}, Fetching details...", file=sys.stderr)
                detail_url = f"https://project.ssafy.com/ssafy/api/courses/{course_id}/practices/{pr_id}/answers/{pa_id}"
                
                try:
                    res_detail = api_request(detail_url, method="GET", headers=HEADERS)
                    
                    if res_detail.status_code == 200:
                        repo = res_detail.json().get('repositoryUrl')
                        if repo:
                            result = (repo, pa_id)
                            REPO_CACHE[pr_id] = result
                            return result
                        else:
                             print(f"⚠️ [Detail No Repo] {res_detail.text[:100]}", file=sys.stderr)
                    else:
                        print(f"⚠️ [Detail Fail] Status {res_detail.status_code} Body {res_detail.text[:100]}", file=sys.stderr)
                except Exception as e:
                    print(f"⚠️ [Detail Error] {e}", file=sys.stderr)

            # 2.4 여전히 없으면 재시도
            if attempt < max_retries - 1:
                print(f"⚠️ [Retry {attempt+1}/{max_retries}] {pr_id}: Status {status} (No URL), Retrying...", file=sys.stderr)
                time.sleep(1.5) 
            else:
                 print(f"❌ [GiveUp] {pr_id}: Status {status}", file=sys.stderr)
                 try:
                     print(f"   [Body]: {res.text[:300]}", file=sys.stderr)
                 except: pass

        except Exception as e:
            print(f"Error fetching {pr_id}: {e}", file=sys.stderr)
            time.sleep(1)
            
    return (None, None)

def find_round_start(course_id, start_pr_num):
    """
    입력된 PR부터 뒤로 검색하여, '같은 차시(Round)'가 시작되는 지점을 찾습니다.
    예: 입력이 ws_3_1(Round 3)인데 그 앞에 hw_3_2(Round 3)가 있다면 거기까지 거슬러 올라감.
    """
    current_pr_num = start_pr_num
    
    # 기준 Round 파악
    base_repo, _ = get_repo_info(course_id, f"PR{str(current_pr_num).zfill(8)}")
    target_round = detect_round_from_repo(base_repo)
    
    if not target_round:
        return start_pr_num, None 

    # 최대 15칸 뒤로 검색
    limit = 15
    found_start = start_pr_num
    
    for i in range(1, limit + 1):
        prev_num = start_pr_num - i
        prev_id = f"PR{str(prev_num).zfill(8)}"
        
        repo, _ = get_repo_info(course_id, prev_id)
        rnd = detect_round_from_repo(repo)
        
        if rnd == target_round:
            found_start = prev_num
        else:
            if rnd is not None: 
                break
            break
            
    return found_start, target_round

def batch_create(start_url, count, is_pipe=False):
    course_id, start_pr, _ = parse_url(start_url)
    
    if not course_id or not start_pr:
        print("❌ URL 형식이 올바르지 않습니다.", file=sys.stderr)
        return
    
    start_num_input = int(start_pr.replace("PR", ""))
    
    print(f"🚀 [Smart Batch] 기준점 분석 중...", file=sys.stderr)

    # [1] 시작점 보정 (백워드 스캔)
    real_start_num, target_round = find_round_start(course_id, start_num_input)
    
    print(f"💡 Target Round: {target_round}", file=sys.stderr)
    print(f"👉 시작지점 조정: {start_pr} -> PR{str(real_start_num).zfill(8)}", file=sys.stderr)
    print("-" * 60, file=sys.stderr)
    
    # [2] 포워드 스캔 & 수집
    found_items = []
    failed_items = []
    
    for i in range(count):
        curr_num = real_start_num + i
        pr_id = f"PR{str(curr_num).zfill(8)}" 
        
        repo_url, pa_id = get_repo_info(course_id, pr_id)
        
        print(f"👉 {pr_id} 확인... ", end="", file=sys.stderr)
        
        if repo_url: 
            print(f"✅ {repo_url}", file=sys.stderr)
            
            curr_rnd = detect_round_from_repo(repo_url)
            
            # [Strict Round Check] 라운드가 다르면 리스트에 추가하지 않고 즉시 종료
            if target_round and curr_rnd and curr_rnd != target_round:
                print(f"🛑 차시 변경 감지 (Round {target_round} -> {curr_rnd}). 스캔 종료.", file=sys.stderr)
                break
                
            # 성공 목록에 추가
            found_items.append({'url': repo_url, 'pa': pa_id, 'pr': pr_id})

        else: 
            print(f"❌ (실패/없음)", file=sys.stderr)
            failed_items.append((course_id, pr_id))
            
        time.sleep(0.1)

    # [3] Retry Phase
    if failed_items:
        print(f"\n🔄 [Retry Phase] 실패한 {len(failed_items)}개 항목 재시도 (5초 대기)...", file=sys.stderr)
        time.sleep(5)
        
        for cid, pid in failed_items:
            print(f"👉 [Retry] {pid} 재확인... ", end="", file=sys.stderr)
            repo_url, pa_id = get_repo_info(cid, pid)
            if repo_url:
                print(f"✅ 복구 성공: {repo_url}", file=sys.stderr)
                
                # Retry 시에도 라운드 체크 (혹시 모르니)
                c_rnd = detect_round_from_repo(repo_url)
                if target_round and c_rnd and c_rnd != target_round:
                     print(f"⚠️ [Retry Skip] 라운드 불일치 ({c_rnd})", file=sys.stderr)
                     continue
                     
                found_items.append({'url': repo_url, 'pa': pa_id, 'pr': pid})
            else:
                print(f"❌ 최종 실패", file=sys.stderr)

    print("-" * 60, file=sys.stderr)
    
    # [4] 정렬 및 출력 (User Request: PA순 정렬, HW는 맨 뒤)
    # 중복 제거 (pr_id 기준으로)
    unique_found_items = {}
    for item in found_items:
        unique_found_items[item['pr']] = item
    found_items = list(unique_found_items.values())

    # 정렬 키: (is_hw 오름차순, pa_id 오름차순) -> is_hw=False(0)가 먼저, HW(1)가 나중
    def sort_key(item):
        is_hw = 1 if '_hw_' in item['url'] else 0
        return (is_hw, item['pa'])
        
    found_items.sort(key=sort_key)
    
    print(f"📦 총 {len(found_items)}개의 저장소를 처리합니다. (PA순 정렬 + HW 후순위)", file=sys.stderr)
    
    for item in found_items:
        url = item['url']
        if is_pipe:
            print(url)
            sys.stdout.flush()
        print(f"✅ [Sorted] {item['url']} (PA: {item['pa']})", file=sys.stderr)
            
    print(f"🏁 작업 완료.", file=sys.stderr)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python ssafy_batch_create.py <URL> [COUNT] [--pipe]")
        sys.exit(1)
        
    url = sys.argv[1]
    cnt = 20
    pipe = False
    
    # 간단한 파싱
    args = sys.argv[2:]
    filtered_args = []
    for a in args:
        if a == "--pipe":
            pipe = True
        else:
            try:
                cnt = int(a)
            except:
                pass
            
    batch_create(url, cnt, is_pipe=pipe)
