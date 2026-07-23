"""Stable expected-red checker for runtime diagnostics."""

from __future__ import annotations

import json
import pathlib


root = pathlib.Path(__file__).resolve().parents[1]
answers = json.loads((root / "answers.json").read_text())
todo = [
    f"{case}.{field}"
    for case, fields in answers.items()
    for field, value in fields.items()
    if value == "TODO"
]
if todo:
    raise SystemExit(f"EXPECTED RED: complete {', '.join(todo)}")
oracle = {
    "global_vs_project": {"first_evidence": "sys-executable-prefix", "fix": "run-via-uv-and-align-ide"},
    "stale_lock": {"first_evidence": "uv-lock-check", "fix": "update-and-review-lock"},
    "module_shadowing": {"first_evidence": "module-file", "fix": "rename-local-module"},
}
assert answers == oracle
print("PASS: runtime diagnosis answers")
