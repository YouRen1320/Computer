from datetime import UTC, datetime
import json
from pathlib import Path
import tempfile

from snapshot_store import load_snapshot, parse_instant, save_snapshot

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    instant = datetime(2026, 7, 24, 3, 4, 5, tzinfo=UTC)
    orders = [{"id": "WO-1", "summary": "南京泵站异响"}]
    save_snapshot(root, "daily_1", orders, instant)
    loaded = load_snapshot(root, "daily_1")
    assert loaded["orders"] == orders
    assert parse_instant(loaded["generatedAt"]) == instant
    assert "南京" in (root / "daily_1.json").read_text(encoding="utf-8")

    old_text = (root / "daily_1.json").read_text(encoding="utf-8")
    try:
        save_snapshot(root, "daily_1", [{"score": float("nan")}], instant)
    except ValueError:
        pass
    else:
        raise AssertionError("NaN must be rejected")
    assert (root / "daily_1.json").read_text(encoding="utf-8") == old_text
    assert not list(root.glob("*.tmp"))

    (root / "broken.json").write_bytes(b"\xff\xfe")
    try:
        load_snapshot(root, "broken")
    except UnicodeDecodeError:
        pass
    else:
        raise AssertionError("invalid UTF-8 must fail")

    bounded = root / "bounded.json"
    bounded.write_text(json.dumps({
        "schemaVersion": 1,
        "generatedAt": instant.isoformat(),
        "orders": [],
    }), encoding="utf-8")
    boundary = len(bounded.read_bytes())
    assert load_snapshot(root, "bounded", max_bytes=boundary)["orders"] == []
    try:
        load_snapshot(root, "bounded", max_bytes=boundary - 1)
    except ValueError as error:
        assert str(error) == "snapshot exceeds byte limit"
    else:
        raise AssertionError("one byte above the configured limit must fail")

print("PASS files/json/time example: roundtrip, strict UTF-8, exact size boundary and old-file protection hold")
