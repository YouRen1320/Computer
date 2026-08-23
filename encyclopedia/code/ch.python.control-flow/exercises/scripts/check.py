"""Expect three bounded retry iterations."""

from __future__ import annotations

import pathlib
import subprocess
import sys


root = pathlib.Path(__file__).resolve().parents[1]
completed = subprocess.run(
    [sys.executable, str(root / "retries.py")],
    check=True,
    capture_output=True,
    text=True,
)
expected = "attempt=1\nattempt=2\nattempt=3\n"
assert completed.stdout == expected, f"EXPECTED RED: expected {expected!r}, got {completed.stdout!r}"
print("PASS: range includes exactly attempts 1..3")
