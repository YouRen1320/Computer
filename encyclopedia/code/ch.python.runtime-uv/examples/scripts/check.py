"""Validate the probe's evidence boundary."""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys


root = pathlib.Path(__file__).resolve().parents[1]
completed = subprocess.run(
    [sys.executable, str(root / "probe.py")],
    check=True,
    capture_output=True,
    text=True,
)
data = json.loads(completed.stdout)
assert data["implementation"] == "CPython", data
assert data["version"][:2] == [3, 14], data
assert pathlib.Path(data["executable"]).resolve() == pathlib.Path(sys.executable).resolve()
assert pathlib.Path(data["json_module"]).name == "__init__.py"
assert str(root) not in data["json_module"]
print("PASS: CPython 3.14 interpreter and stdlib source are explicit")
