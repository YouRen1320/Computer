"""Expected-red oracle: the exercise target must become strict-green."""

from __future__ import annotations

import os
import pathlib
import subprocess


root = pathlib.Path(__file__).resolve().parents[1]
environment = dict(os.environ)
environment["UV_NO_PROGRESS"] = "1"
completed = subprocess.run(
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
assert completed.returncode == 0, (
    "EXPECTED RED: repair contracts without Any/ignore:\n"
    + completed.stdout
    + completed.stderr
)
print("PASS: public typing exercise is strict-green")
