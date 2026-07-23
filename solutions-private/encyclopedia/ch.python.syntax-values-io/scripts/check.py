"""Validate the private amount solution."""

from __future__ import annotations

import pathlib
import subprocess
import sys


root = pathlib.Path(__file__).resolve().parents[1]
completed = subprocess.run(
    [sys.executable, str(root / "amount.py")],
    check=True,
    capture_output=True,
    text=True,
)
assert completed.stdout == "5997\n"
assert completed.stderr == ""
print("PASS: private conversion solution")
