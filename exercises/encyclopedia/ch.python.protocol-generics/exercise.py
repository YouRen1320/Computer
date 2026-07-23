"""Public exercise with an intentional structural contract drift."""

from dataclasses import dataclass


@dataclass(frozen=True)
class WorkOrder:
    id: int


class BrokenRepository:
    def __init__(self) -> None:
        self.items: dict[int, WorkOrder] = {}

    def get(self, entity_id: int) -> WorkOrder | None:
        return self.items.get(entity_id)

    def store(self, entity: WorkOrder) -> None:
        self.items[entity.id] = entity
