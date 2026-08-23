"""Public exercise with an intentional structural contract drift."""

from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class PrioritySuggestion:
    id: int
    level: int


class SuggestionRepository(Protocol):
    def get(self, entity_id: int) -> PrioritySuggestion | None: ...

    def save(self, entity: PrioritySuggestion) -> None: ...


class BrokenRepository:
    def __init__(self) -> None:
        self.items: dict[int, PrioritySuggestion] = {}

    def get(self, entity_id: int) -> PrioritySuggestion | None:
        return self.items.get(entity_id)

    def store(self, entity: PrioritySuggestion) -> None:
        self.items[entity.id] = entity


def persist(repository: SuggestionRepository, entity: PrioritySuggestion) -> None:
    repository.save(entity)
