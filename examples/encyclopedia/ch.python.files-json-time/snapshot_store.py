from __future__ import annotations

from datetime import UTC, datetime
import json
import os
from pathlib import Path
import re
import tempfile
from typing import Any

_SAFE_ID = re.compile(r"^[A-Za-z0-9_-]+$")


def format_instant(value: datetime) -> str:
    if value.tzinfo is None or value.utcoffset() is None:
        raise ValueError("timestamp must be timezone-aware")
    return value.astimezone(UTC).isoformat(timespec="microseconds")


def parse_instant(raw: str) -> datetime:
    parsed = datetime.fromisoformat(raw)
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError("timestamp must include an offset")
    return parsed.astimezone(UTC)


def _reject_constant(token: str) -> None:
    raise ValueError(f"non-finite JSON number: {token}")


class DerivedSnapshotStore:
    def __init__(self, root: Path, *, max_bytes: int = 100_000) -> None:
        self._root = root.resolve(strict=True)
        self._max_bytes = max_bytes

    def _path(self, snapshot_id: str) -> Path:
        if not _SAFE_ID.fullmatch(snapshot_id):
            raise ValueError("invalid snapshot id")
        candidate = (self._root / f"{snapshot_id}.json").resolve(strict=False)
        if not candidate.is_relative_to(self._root):
            raise ValueError("path escapes storage root")
        return candidate

    def save(
        self,
        snapshot_id: str,
        orders: list[dict[str, Any]],
        generated_at: datetime,
    ) -> None:
        document = {
            "schemaVersion": 1,
            "generatedAt": format_instant(generated_at),
            "orders": orders,
        }
        text = json.dumps(
            document,
            ensure_ascii=False,
            allow_nan=False,
            sort_keys=True,
            indent=2,
        ) + "\n"
        self._atomic_write(self._path(snapshot_id), text)

    def load(self, snapshot_id: str) -> dict[str, Any]:
        raw = self._path(snapshot_id).read_bytes()
        if len(raw) > self._max_bytes:
            raise ValueError("snapshot exceeds byte limit")
        text = raw.decode("utf-8", errors="strict")
        value = json.loads(text, parse_constant=_reject_constant)
        if not isinstance(value, dict):
            raise ValueError("snapshot root must be an object")
        if value.get("schemaVersion") != 1:
            raise ValueError("unsupported schemaVersion")
        generated_at = value.get("generatedAt")
        if not isinstance(generated_at, str):
            raise ValueError("generatedAt must be a string")
        parse_instant(generated_at)
        if not isinstance(value.get("orders"), list):
            raise ValueError("orders must be an array")
        return value

    @staticmethod
    def _atomic_write(target: Path, text: str) -> None:
        temporary_name: str | None = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w",
                encoding="utf-8",
                newline="\n",
                dir=target.parent,
                prefix=f".{target.name}.",
                suffix=".tmp",
                delete=False,
            ) as stream:
                temporary_name = stream.name
                stream.write(text)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary_name, target)
            temporary_name = None
        finally:
            if temporary_name is not None:
                Path(temporary_name).unlink(missing_ok=True)
