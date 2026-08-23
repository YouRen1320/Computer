"""Private structural repository solution."""

from dataclasses import dataclass


@dataclass(frozen=True)
class PrioritySuggestion:
    id: int
    level: int


class Repository:
    def __init__(self) -> None:
        self.items: dict[int, PrioritySuggestion] = {}

    def get(self, entity_id: int) -> PrioritySuggestion | None:
        return self.items.get(entity_id)

    def save(self, entity: PrioritySuggestion) -> None:
        self.items[entity.id] = entity
