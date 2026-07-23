"""Check successful replacement and failure preservation."""

from __future__ import annotations

import hashlib
import pathlib
import sys
import tempfile


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from atomic_store import StoreWriteError, write_json  # noqa: E402


with tempfile.TemporaryDirectory() as directory:
    target = pathlib.Path(directory) / "orders.json"
    target.write_text('[{"id":0}]\n', encoding="utf-8")
    write_json(target, [{"id": 1, "status": "ASSIGNED"}])
    assert target.read_text(encoding="utf-8") == '[{"id": 1, "status": "ASSIGNED"}]\n'
    before = hashlib.sha256(target.read_bytes()).hexdigest()
    try:
        write_json(target, {"invalid": object()})
    except StoreWriteError as error:
        assert isinstance(error.__cause__, TypeError)
    else:
        raise AssertionError("unserializable payload did not fail")
    after = hashlib.sha256(target.read_bytes()).hexdigest()
    assert before == after
    assert list(pathlib.Path(directory).iterdir()) == [target]
print("PASS: failure keeps the original file and cleans the temporary file")
