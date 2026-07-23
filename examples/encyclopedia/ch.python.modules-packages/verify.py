from __future__ import annotations

import contextlib
import importlib
import io
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"
sys.path.insert(0, str(SRC))

captured = io.StringIO()
with contextlib.redirect_stdout(captured):
    first = importlib.import_module("factorycare_training.priority")
    second = importlib.import_module("factorycare_training.priority")

assert captured.getvalue() == "", "导入领域模块不应输出"
assert first is second, "重复普通导入应命中同一模块缓存"
assert first.normalize_priority(4) == 4

environment = os.environ | {"PYTHONPATH": str(SRC)}
success = subprocess.run(
    [sys.executable, "-m", "factorycare_training", "--priority", "5"],
    cwd=ROOT,
    env=environment,
    text=True,
    capture_output=True,
    check=False,
)
assert success.returncode == 0, success.stderr
assert success.stdout.strip() == "5"

failure = subprocess.run(
    [sys.executable, "-m", "factorycare_training", "--priority", "9"],
    cwd=ROOT,
    env=environment,
    text=True,
    capture_output=True,
    check=False,
)
assert failure.returncode != 0
assert "priority must be between 1 and 5" in failure.stderr
print("PASS modules example: import/cache/module CLI contracts hold")
