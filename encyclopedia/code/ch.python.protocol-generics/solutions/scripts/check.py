"""Validate the private structural solution."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from solution import PrioritySuggestion, Repository  # noqa: E402


repo = Repository()
repo.save(PrioritySuggestion(1, 4))
assert repo.get(1) == PrioritySuggestion(1, 4)
print("PASS: private Protocol member solution")
