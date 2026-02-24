#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python - "$ROOT_DIR" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
targets = [
    root / "algo_functions.sh",
    root / "install.sh",
    root / "lib" / "git.sh",
    root / "lib" / "update.sh",
    root / "README.md",
    root / "updatenote.md",
]

# Known mojibake fragments previously observed in runtime outputs.
bad_fragments = [
    "????",
    "?낅",
    "?쒖",
    "怨몄",
    "留덉",
    "吏꾪",
]

failures = []
for path in targets:
    raw = path.read_bytes()
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        failures.append(f"{path}: not valid UTF-8 ({exc})")
        continue

    for frag in bad_fragments:
        if frag in text:
            failures.append(f"{path}: contains mojibake fragment '{frag}'")
            break

if failures:
    print("FAIL: encoding smoke")
    for item in failures:
        print(f"  - {item}")
    sys.exit(1)

print("PASS: encoding smoke")
PY
