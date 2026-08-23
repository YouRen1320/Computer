"""Exercise the sentinel loop with bounded subprocess runs."""

from __future__ import annotations

import pathlib
import subprocess
import sys


root = pathlib.Path(__file__).resolve().parents[1]
cases = [
    ("q\n", "valid=0,urgent=0\n"),
    ("5\n2\n4\nq\n", "valid=3,urgent=2\n"),
    ("0\n1\n6\nq\n", "INVALID\nINVALID\nvalid=1,urgent=0\n"),
]
for stdin, expected in cases:
    completed = subprocess.run(
        [sys.executable, str(root / "count.py")],
        input=stdin,
        capture_output=True,
        text=True,
        timeout=2,
        check=False,
    )
    assert completed.returncode == 0, completed.stderr
    assert completed.stdout == expected, (stdin, completed.stdout, expected)
print("PASS: sentinel, invalid and mixed loops terminate with correct invariants")
