"""Verify both static and runtime contracts for the private solution."""

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
        str(root / "typed_summary.py"),
    ],
    capture_output=True,
    text=True,
    env=environment,
    check=False,
)
assert checked.returncode == 0, checked.stdout + checked.stderr

sys.path.insert(0, str(root))
from typed_summary import collect_priorities, count_active, display_name


assert display_name(None) == "未命名"
assert display_name("pump") == "PUMP"
assert collect_priorities() == [1, 2, 4]
assert count_active() == 2
print("PASS: private typing solution is static-green and behavior-green")
