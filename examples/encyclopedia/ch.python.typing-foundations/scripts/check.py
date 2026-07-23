"""Run a real checker and a separate CPython runtime contrast."""

from __future__ import annotations

import os
import pathlib
import subprocess
import sys


root = pathlib.Path(__file__).resolve().parents[1]
environment = dict(os.environ)
environment["UV_NO_PROGRESS"] = "1"

checked = subprocess.run(
    [
        "uvx",
        "--from",
        "mypy==2.3.0",
        "mypy",
        "--strict",
        "--no-incremental",
        "--cache-dir=/dev/null",
        "--python-version",
        "3.14",
        "--show-error-codes",
        str(root / "typed_counts.py"),
    ],
    capture_output=True,
    text=True,
    env=environment,
    check=False,
)
assert checked.returncode == 0, checked.stdout + checked.stderr
assert "Success: no issues found" in checked.stdout

runtime = subprocess.run(
    [sys.executable, str(root / "runtime_contrast.py")],
    capture_output=True,
    text=True,
    check=True,
)
assert runtime.stdout == "value=three,runtime_type=str\n"
assert runtime.stderr == ""
print("PASS: mypy strict is green and CPython proves annotations do not validate")
