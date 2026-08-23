"""Two structural implementations of one generic port."""

from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
import tempfile
from typing import Protocol, TypeVar


T = TypeVar("T")


class Repository(Protocol[T]):
    def get(self, entity_id: int) -> T | None: ...

    def save(self, entity: T) -> None: ...


@dataclass(frozen=True)
class PrioritySuggestion:
    id: int
    order_id: str
    level: int


class MemoryRepository:
    def __init__(self) -> None:
        self.items: dict[int, PrioritySuggestion] = {}

    def get(self, entity_id: int) -> PrioritySuggestion | None:
        return self.items.get(entity_id)

    def save(self, entity: PrioritySuggestion) -> None:
        self.items[entity.id] = entity


class JsonFileRepository:
    def __init__(self, root: Path) -> None:
        self.root = root.resolve(strict=True)

    def _path(self, entity_id: int) -> Path:
        if entity_id < 1:
            raise ValueError("entity id must be positive")
        return self.root / f"suggestion-{entity_id}.json"

    def get(self, entity_id: int) -> PrioritySuggestion | None:
        path = self._path(entity_id)
        if not path.exists():
            return None
        value: object = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(value, dict):
            raise ValueError("suggestion document must be an object")
        stored_id = value.get("id")
        order_id = value.get("orderId")
        level = value.get("level")
        if not isinstance(stored_id, int) or not isinstance(order_id, str) or not isinstance(level, int):
            raise ValueError("invalid suggestion document")
        return PrioritySuggestion(id=stored_id, order_id=order_id, level=level)

    def save(self, entity: PrioritySuggestion) -> None:
        target = self._path(entity.id)
        text = json.dumps(
            {"id": entity.id, "orderId": entity.order_id, "level": entity.level},
            ensure_ascii=False,
            allow_nan=False,
            sort_keys=True,
        ) + "\n"
        temporary_name: str | None = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w",
                encoding="utf-8",
                dir=self.root,
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


def assert_contract(repository: Repository[PrioritySuggestion]) -> None:
    assert repository.get(7) is None
    expected = PrioritySuggestion(7, "WO-7", 4)
    repository.save(expected)
    assert repository.get(7) == expected
