"""Run one contract suite against both structural implementations."""

from __future__ import annotations

import pathlib
import sys
import tempfile


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from lab import JsonFileRepository, MemoryRepository, PrioritySuggestion, assert_contract  # noqa: E402


assert_contract(MemoryRepository())
with tempfile.TemporaryDirectory() as directory:
    root_path = pathlib.Path(directory)
    file_repository = JsonFileRepository(root_path)
    assert_contract(file_repository)
    assert (root_path / "suggestion-7.json").is_file()
    assert JsonFileRepository(root_path).get(7) == PrioritySuggestion(7, "WO-7", 4)
print("PASS: memory and real JSON-file implementations satisfy one static/runtime contract")
