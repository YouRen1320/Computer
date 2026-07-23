"""Generic structural repository example for Python 3.14."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol, TypeVar


T = TypeVar("T")


class Repository(Protocol[T]):
    def get(self, entity_id: int) -> T | None: ...

    def save(self, entity: T) -> None: ...


@dataclass(frozen=True, slots=True)
class WorkOrder:
    id: int
    status: str


class MemoryRepository:
    def __init__(self) -> None:
        self._items: dict[int, WorkOrder] = {}

    def get(self, entity_id: int) -> WorkOrder | None:
        return self._items.get(entity_id)

    def save(self, entity: WorkOrder) -> None:
        self._items[entity.id] = entity


def close_order(repository: Repository[WorkOrder], order_id: int) -> WorkOrder:
    order = repository.get(order_id)
    if order is None:
        raise LookupError(order_id)
    closed = WorkOrder(id=order.id, status="CLOSED")
    repository.save(closed)
    return closed
