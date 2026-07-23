"""Validate the private half-open range solution."""

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
assert completed.stdout == "attempt=1\nattempt=2\nattempt=3\n"
print("PASS: private range solution")
