"""Require a green positive fixture and specific red negative diagnostics."""

from __future__ import annotations

import os
import pathlib
import subprocess


root = pathlib.Path(__file__).resolve().parents[1]
environment = dict(os.environ)
environment["UV_NO_PROGRESS"] = "1"
base = [
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
]

positive = subprocess.run(
    [*base, str(root / "positive.py")],
    capture_output=True,
    text=True,
    env=environment,
    check=False,
)
assert positive.returncode == 0, positive.stdout + positive.stderr
assert "Success: no issues found" in positive.stdout

negative = subprocess.run(
    [*base, str(root / "negative.py")],
    capture_output=True,
    text=True,
    env=environment,
    check=False,
)
diagnostics = negative.stdout + negative.stderr
assert negative.returncode != 0, "negative fixture unexpectedly passed"
for marker in ("[union-attr]", "[return-value]", "[list-item]"):
    assert marker in diagnostics, f"missing expected diagnostic {marker}:\n{diagnostics}"
assert "negative.py" in diagnostics
print("PASS: positive fixture green; negative fixture fails at three typed boundaries")
