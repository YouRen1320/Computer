"""Expect the learner to repair the type conversion bug."""

from __future__ import annotations

import pathlib
import subprocess
import sys


root = pathlib.Path(__file__).resolve().parents[1]
completed = subprocess.run(
    [sys.executable, str(root / "amount.py")],
    capture_output=True,
    text=True,
)
if completed.returncode != 0:
    raise SystemExit(f"EXPECTED RED: amount.py failed at runtime\n{completed.stderr}")
assert completed.stdout == "5997\n", f"EXPECTED RED: expected 5997, got {completed.stdout!r}"
print("PASS: conversion and amount are correct")
