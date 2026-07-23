from datetime import UTC, datetime
import json
from pathlib import Path
import tempfile

from snapshot_store import DerivedSnapshotStore, parse_instant

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    store = DerivedSnapshotStore(root)
    instant = datetime(2026, 7, 24, 3, 4, 5, tzinfo=UTC)
    orders = [{"id": "WO-1", "summary": "南京泵站异响"}]
    store.save("daily_1", orders, instant)
    loaded = store.load("daily_1")
    assert loaded["orders"] == orders
    assert parse_instant(loaded["generatedAt"]) == instant
    assert "南京" in (root / "daily_1.json").read_text(encoding="utf-8")

    old_text = (root / "daily_1.json").read_text(encoding="utf-8")
    try:
        store.save("daily_1", [{"score": float("nan")}], instant)
    except ValueError:
        pass
    else:
        raise AssertionError("NaN must be rejected")
    assert (root / "daily_1.json").read_text(encoding="utf-8") == old_text
    assert not list(root.glob("*.tmp"))

    (root / "broken.json").write_bytes(b"\xff\xfe")
    try:
        store.load("broken")
    except UnicodeDecodeError:
        pass
    else:
        raise AssertionError("invalid UTF-8 must fail")

print("PASS files/json/time example: roundtrip, strict UTF-8 and old-file protection hold")
