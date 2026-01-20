#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, asdict
from pathlib import Path


@dataclass
class TestResults:
    ok: bool
    exit_code: int
    runner: str
    command: list[str]
    started_at: float
    ended_at: float
    passed: list[str]
    failed: list[str]


def _which_any(names: list[str]) -> str | None:
    for name in names:
        path = shutil.which(name)
        if path:
            return path
    return None


def _default_runner() -> str:
    if _which_any(["bash", "bash.exe"]):
        return "bash"
    return "powershell"


def _build_command(root: Path, runner: str) -> list[str]:
    tests_dir = root / "tests"
    if runner == "bash":
        bash = _which_any(["bash", "bash.exe"])
        if not bash:
            raise RuntimeError("bash not found (install Git Bash or add bash to PATH).")
        return [bash, str(tests_dir / "run_tests.sh")]

    if runner == "powershell":
        pwsh = _which_any(["pwsh"])
        if pwsh:
            return [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(tests_dir / "run_tests.ps1")]
        powershell = _which_any(["powershell", "powershell.exe"])
        if not powershell:
            raise RuntimeError("powershell not found.")
        return [powershell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(tests_dir / "run_tests.ps1")]

    raise ValueError(f"unknown runner: {runner}")


def _run_and_tee(command: list[str], cwd: Path) -> tuple[int, list[str]]:
    lines: list[str] = []
    proc = subprocess.Popen(
        command,
        cwd=str(cwd),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )
    assert proc.stdout is not None
    for line in proc.stdout:
        sys.stdout.write(line)
        lines.append(line.rstrip("\n"))
    proc.wait()
    return int(proc.returncode), lines


def _parse(lines: list[str]) -> tuple[list[str], list[str]]:
    passed: list[str] = []
    failed: list[str] = []
    for line in lines:
        if line.startswith("PASS: "):
            passed.append(line[len("PASS: ") :].strip())
        elif line.startswith("FAIL: "):
            failed.append(line[len("FAIL: ") :].strip())
    return passed, failed


def main() -> int:
    root = Path(__file__).resolve().parents[1]

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Run repo tests and optionally write results JSON.")
    parser.add_argument("--runner", choices=["bash", "powershell"], default=None)
    parser.add_argument("--out", default=str(root / "tests" / "test_results.json"))
    args = parser.parse_args()

    runner = args.runner or _default_runner()
    command = _build_command(root, runner)

    started = time.time()
    exit_code, lines = _run_and_tee(command, cwd=root)
    ended = time.time()

    passed, failed = _parse(lines)
    results = TestResults(
        ok=(exit_code == 0),
        exit_code=exit_code,
        runner=runner,
        command=command,
        started_at=started,
        ended_at=ended,
        passed=passed,
        failed=failed,
    )

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(asdict(results), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"\nWrote: {out_path}")

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
