"""Run the script with deterministic stdin/stdout."""

from __future__ import annotations

import pathlib
import subprocess
import sys


root = pathlib.Path(__file__).resolve().parents[1]
completed = subprocess.run(
    [sys.executable, str(root / "amount.py")],
    input=(root / "fixtures/success.stdin").read_text(),
    capture_output=True,
    text=True,
    check=False,
)
expected = (root / "fixtures/success.stdout").read_text()
assert completed.returncode == 0, completed.stderr
assert completed.stdout == expected, (completed.stdout, expected)
assert completed.stderr == "", completed.stderr
print("PASS: fixed stdin produces the predicted names, types and amount")
