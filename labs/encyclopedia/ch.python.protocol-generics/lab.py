"""Two structural implementations of one generic port."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Protocol, TypeVar


T = TypeVar("T")


class Repository(Protocol[T]):
    def get(self, entity_id: int) -> T | None: ...

    def save(self, entity: T) -> None: ...


@dataclass(frozen=True)
class WorkOrder:
    id: int
    status: str


class MemoryRepository:
    def __init__(self) -> None:
        self.items: dict[int, WorkOrder] = {}

    def get(self, entity_id: int) -> WorkOrder | None:
        return self.items.get(entity_id)

    def save(self, entity: WorkOrder) -> None:
        self.items[entity.id] = entity


class JsonLikeRepository:
    def __init__(self) -> None:
        self.rows: dict[str, dict[str, object]] = {}

    def get(self, entity_id: int) -> WorkOrder | None:
        row = self.rows.get(str(entity_id))
        return None if row is None else WorkOrder(id=int(row["id"]), status=str(row["status"]))

    def save(self, entity: WorkOrder) -> None:
        self.rows[str(entity.id)] = asdict(entity)


def assert_contract(repository: Repository[WorkOrder]) -> None:
    assert repository.get(7) is None
    expected = WorkOrder(7, "IN_PROGRESS")
    repository.save(expected)
    assert repository.get(7) == expected
