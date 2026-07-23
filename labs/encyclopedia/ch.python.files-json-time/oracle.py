from datetime import UTC, datetime
import json
from pathlib import Path
import tempfile


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

    target = root / "snapshot.json"
    target.write_text("old", encoding="utf-8")
    temporary = root / ".snapshot.tmp"
    temporary.write_text("partial", encoding="utf-8")
    temporary.unlink()
    assert target.read_text(encoding="utf-8") == "old"

print("PASS files/json/time lab: boundary failures classified without corrupting old data")
