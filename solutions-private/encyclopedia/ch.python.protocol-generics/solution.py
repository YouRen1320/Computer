"""Private structural repository solution."""

from dataclasses import dataclass


@dataclass(frozen=True)
class WorkOrder:
    id: int


class Repository:
    def __init__(self) -> None:
        self.items: dict[int, WorkOrder] = {}

    def get(self, entity_id: int) -> WorkOrder | None:
        return self.items.get(entity_id)

    def save(self, entity: WorkOrder) -> None:
        self.items[entity.id] = entity
