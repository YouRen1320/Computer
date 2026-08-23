"""Stable expected-red structural contract check."""

from __future__ import annotations

import os
import pathlib
import subprocess
import sys


root = pathlib.Path(__file__).resolve().parents[1]
environment = dict(os.environ)
environment["UV_NO_PROGRESS"] = "1"
checked = subprocess.run(
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
        str(root / "exercise.py"),
        str(root / "type_fixture.py"),
    ],
    capture_output=True,
    text=True,
    env=environment,
    check=False,
)
if checked.returncode != 0:
    diagnostic = checked.stdout + checked.stderr
    assert "BrokenRepository" in diagnostic and "[arg-type]" in diagnostic, diagnostic
    raise AssertionError(
        "EXPECTED RED: static Protocol rejects BrokenRepository without save:\n" + diagnostic
    )

sys.path.insert(0, str(root))
from exercise import BrokenRepository, PrioritySuggestion, persist  # noqa: E402


repo = BrokenRepository()
expected = PrioritySuggestion(1, 4)
persist(repo, expected)
assert repo.get(1) == expected
print("PASS: repository is static-green and runtime-green for save/get")
