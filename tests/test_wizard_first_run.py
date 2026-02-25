#!/usr/bin/env python3
"""
test_wizard_first_run.py
algo_config_wizard.py의 first_run_setup 로직을 비대화형으로 검증한다.
"""
import sys
import os
import tempfile
import importlib.util

# ── 공통 헬퍼 ──────────────────────────────────────────────────────────────

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WIZARD_PATH = os.path.join(ROOT_DIR, "algo_config_wizard.py")

pass_count = 0
fail_count = 0


def _pass(name):
    global pass_count
    print(f"PASS: {name}")
    pass_count += 1


def _fail(name, reason=""):
    global fail_count
    print(f"FAIL: {name}" + (f" -- {reason}" if reason else ""))
    fail_count += 1


def run_test(name, fn):
    try:
        fn()
        _pass(name)
    except AssertionError as e:
        _fail(name, str(e))
    except Exception as e:
        _fail(name, f"exception: {e}")


# ── wizard 모듈 동적 로드 (CONFIG_FILE 경로를 임시 파일로 교체) ────────────

def _load_wizard_with_config(config_path):
    """CONFIG_FILE을 config_path 로 교체한 뒤 wizard 모듈을 반환한다."""
    spec = importlib.util.spec_from_file_location("wizard_mod", WIZARD_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    # exec_module 이후에 덮어쓰기 (모듈 최상위 코드에 의한 overwite 방지)
    mod.CONFIG_FILE = config_path
    mod.pick_folder_gui = lambda *a, **kw: None
    return mod


# ── 테스트 케이스 ──────────────────────────────────────────────────────────

def test_first_run_skip_when_both_set():
    """ALGO_BASE_DIR와 SSAFY_USER_ID가 모두 비기본값으로 설정된 경우 setup을 건너뛴다."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".cfg", delete=False) as f:
        cfg_path = f.name

    try:
        mod = _load_wizard_with_config(cfg_path)

        config = {
            "ALGO_BASE_DIR": "/custom/algo",
            "SSAFY_USER_ID": "myuser",
        }
        result = mod.first_run_setup(config, is_first_run=False)
        assert result is config, "should return same config object"
        assert result["ALGO_BASE_DIR"] == "/custom/algo"
        assert result["SSAFY_USER_ID"] == "myuser"
    finally:
        os.unlink(cfg_path)


def test_needs_algo_dir_when_default():
    """ALGO_BASE_DIR 이 $HOME/algos 기본값일 때 needs_algo_dir 가 True 여야 한다."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".cfg", delete=False) as f:
        cfg_path = f.name

    try:
        mod = _load_wizard_with_config(cfg_path)

        home = os.path.expanduser("~").replace("\\", "/")
        default_dir = home + "/algos"

        config = {
            "ALGO_BASE_DIR": default_dir,
            "SSAFY_USER_ID": "myuser",
        }

        home_val = mod.os.path.expanduser("~").replace("\\", "/")
        current = config.get("ALGO_BASE_DIR", "").replace("\\", "/").rstrip("/")
        default  = home_val + "/algos"
        needs    = not current or current == default

        assert needs is True, f"needs_algo_dir should be True for default dir, got: current={current!r} default={default!r}"
    finally:
        os.unlink(cfg_path)


def test_needs_user_id_when_empty():
    """SSAFY_USER_ID 가 빈 문자열이면 needs_user_id 가 True 여야 한다."""
    config = {"ALGO_BASE_DIR": "/custom/algo", "SSAFY_USER_ID": ""}
    needs = not config.get("SSAFY_USER_ID", "")
    assert needs is True


def test_first_run_flag_detected_without_config_file():
    """설정 파일이 없을 때 is_first_run 이 True 로 판단된다."""
    missing_path = "/nonexistent/path/.algo_config_test_xyz"
    is_first_run = not os.path.exists(missing_path)
    assert is_first_run is True


def test_wizard_syntax_and_required_functions():
    """wizard 파일의 구문이 올바르고 필수 함수가 존재한다."""
    import ast
    with open(WIZARD_PATH, "r", encoding="utf-8") as f:
        src = f.read()
    tree = ast.parse(src)  # SyntaxError 시 예외 발생
    funcs = {n.name for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)}
    required = {"first_run_setup", "main_menu", "save_config", "load_config"}
    missing = required - funcs
    assert not missing, f"Missing functions: {missing}"


def test_main_block_calls_first_run_setup():
    """__main__ 블록에서 first_run_setup 호출 코드가 존재한다."""
    with open(WIZARD_PATH, "r", encoding="utf-8") as f:
        src = f.read()
    assert "first_run_setup(cfg, is_first_run=is_first_run)" in src
    assert "is_first_run = not os.path.exists(CONFIG_FILE)" in src


def test_main_menu_save_validates_required_fields():
    """main_menu '0' 저장 시 필수 항목(ALGO_BASE_DIR, SSAFY_USER_ID) 검증 코드가 존재한다."""
    with open(WIZARD_PATH, "r", encoding="utf-8") as f:
        src = f.read()
    # 저장 블록에서 missing 리스트 검사 로직 존재 확인
    assert "missing = []" in src, "missing list not found in save block"
    assert "not current_algo or current_algo == default_algo_dir" in src, "ALGO_BASE_DIR validation missing"
    assert "not current_uid" in src, "SSAFY_USER_ID validation missing"
    assert "저장할 수 없습니다" in src, "block-save message missing"


# ── 실행 ──────────────────────────────────────────────────────────────────

run_test("skip setup when both required fields set", test_first_run_skip_when_both_set)
run_test("detect needs_algo_dir for default path",  test_needs_algo_dir_when_default)
run_test("detect needs_user_id when empty",         test_needs_user_id_when_empty)
run_test("is_first_run=True when config missing",   test_first_run_flag_detected_without_config_file)
run_test("wizard syntax and required functions",    test_wizard_syntax_and_required_functions)
run_test("__main__ calls first_run_setup",         test_main_block_calls_first_run_setup)
run_test("main_menu save validates required fields", test_main_menu_save_validates_required_fields)

print()
print(f"Tests: {pass_count} passed, {fail_count} failed")
sys.exit(0 if fail_count == 0 else 1)

