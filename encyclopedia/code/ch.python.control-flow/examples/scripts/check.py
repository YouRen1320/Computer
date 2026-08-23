"""Compare the complete priority boundary table."""

from __future__ import annotations

import pathlib
import subprocess
import sys


root = pathlib.Path(__file__).resolve().parents[1]
completed = subprocess.run(
    [sys.executable, str(root / "classify.py")],
    check=True,
    capture_output=True,
    text=True,
)
expected = (root / "expected.stdout").read_text()
assert completed.stdout == expected, (completed.stdout, expected)
assert completed.stderr == ""
print("PASS: priority classification covers invalid and threshold boundaries")
