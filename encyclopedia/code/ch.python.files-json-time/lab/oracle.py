from datetime import UTC, datetime
import json
from pathlib import Path
import tempfile

from snapshot_store import save_snapshot


def safe_child(root: Path, name: str) -> Path:
    if not name or Path(name).is_absolute():
        raise ValueError("relative name required")
    resolved_root = root.resolve(strict=True)
    candidate = (resolved_root / name).resolve(strict=False)
    if not candidate.is_relative_to(resolved_root):
        raise ValueError("path escapes root")
    return candidate


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    for bad in ("../secret", "/tmp/secret"):
        try:
            safe_child(root, bad)
        except ValueError:
            pass
        else:
            raise AssertionError(f"path escape accepted: {bad}")

    invalid = root / "invalid.txt"
    invalid.write_bytes(b"valid\xffinvalid")
    try:
        invalid.read_text(encoding="utf-8", errors="strict")
    except UnicodeDecodeError:
        pass
    else:
        raise AssertionError("invalid UTF-8 was hidden")

    broken = root / "broken.json"
    broken.write_text('{"schemaVersion": 1,', encoding="utf-8")
    try:
        json.loads(broken.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        assert error.lineno == 1 and error.colno > 1
    else:
        raise AssertionError("truncated JSON must fail")

    naive = datetime(2026, 7, 24, 3, 0)
    aware = datetime(2026, 7, 24, 3, 0, tzinfo=UTC)
    try:
        _ = naive < aware
    except TypeError:
        pass
    else:
        raise AssertionError("naive/aware ordering must fail")

    generated_at = datetime(2026, 7, 24, 3, 0, tzinfo=UTC)
    save_snapshot(root, "snapshot", [{"version": "old"}], generated_at)
    target = root / "snapshot.json"
    old_bytes = target.read_bytes()

    def fail_before_replace(temporary_path: Path) -> None:
        assert temporary_path.exists()
        raise RuntimeError("injected failure before replace")

    try:
        save_snapshot(
            root,
            "snapshot",
            [{"version": "new"}],
            generated_at,
            before_replace=fail_before_replace,
        )
    except RuntimeError as error:
        assert str(error) == "injected failure before replace"
    else:
        raise AssertionError("injected writer failure must propagate")
    assert target.read_bytes() == old_bytes
    assert not list(root.glob(".snapshot.json.*.tmp"))

print("PASS files/json/time lab: real writer failure preserves old data and cleans temporary files")
