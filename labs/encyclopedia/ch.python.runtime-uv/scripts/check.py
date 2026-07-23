"""Check declarative runtime inputs without mutating the environment."""

from __future__ import annotations

import json
import pathlib
import sys
import tomllib


root = pathlib.Path(__file__).resolve().parents[1]
project = tomllib.loads((root / "pyproject.toml").read_text())
contract = json.loads((root / "environment-contract.json").read_text())
assert project["project"]["requires-python"] == ">=3.14,<3.15"
assert (root / ".python-version").read_text().strip() == "3.14"
assert contract["lock_required"] is True
assert contract["venv_committed"] is False
assert contract["live_uv_sync"] == "unverified"
assert contract["ci_commands"] == [
    "uv lock --check",
    "uv sync --locked",
    "uv run --locked python -m factorycare_runtime_lab",
]
assert sys.version_info[:2] == (3, 14), sys.version
print(f"PASS: declarative inputs are coherent; local interpreter={sys.executable}")
