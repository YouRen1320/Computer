"""Compare the execution trace with a pre-written oracle."""

from __future__ import annotations

import pathlib
import subprocess
import sys


root = pathlib.Path(__file__).resolve().parents[1]
completed = subprocess.run(
    [sys.executable, str(root / "program.py")],
    check=True,
    capture_output=True,
    text=True,
)
expected = (root / "expected.jsonl").read_text()
assert completed.stdout == expected, (completed.stdout, expected)
print("PASS: every binding matches the prediction table")
