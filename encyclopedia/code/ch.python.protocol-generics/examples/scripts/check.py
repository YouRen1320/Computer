"""Run substitution and annotation relationship checks."""

from __future__ import annotations

import pathlib
import sys
from typing import get_type_hints


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from repository import MemoryRepository, PrioritySuggestion, mark_reviewed  # noqa: E402


repo = MemoryRepository()
assert repo.get(1) is None
repo.save(PrioritySuggestion(id=1, order_id="WO-1", level=4))
reviewed = mark_reviewed(repo, 1)
assert reviewed == PrioritySuggestion(id=1, order_id="WO-1", level=4, reviewed=True)
assert repo.get(1) == reviewed
hints = get_type_hints(mark_reviewed)
assert hints["return"] is PrioritySuggestion
print("PASS: structural MemoryRepository satisfies the runtime contract")
