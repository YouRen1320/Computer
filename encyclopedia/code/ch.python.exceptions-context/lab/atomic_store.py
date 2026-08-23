"""A small same-directory replace boundary for the lab."""

from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path


class StoreWriteError(Exception):
    """The store could not produce a complete replacement."""


def write_json(path: Path, payload: object) -> None:
    temp_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            "w", encoding="utf-8", dir=path.parent, delete=False
        ) as stream:
            temp_path = Path(stream.name)
            json.dump(payload, stream, ensure_ascii=False, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        temp_path.replace(path)
        temp_path = None
    except (OSError, TypeError, ValueError) as error:
        raise StoreWriteError("cannot write JSON store") from error
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)
