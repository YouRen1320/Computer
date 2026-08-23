"""Generic structural repository example for Python 3.14."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol, TypeVar


T = TypeVar("T")


class Repository(Protocol[T]):
    def get(self, entity_id: int) -> T | None: ...

    def save(self, entity: T) -> None: ...


@dataclass(frozen=True, slots=True)
class PrioritySuggestion:
    id: int
    order_id: str
    level: int
    reviewed: bool = False


class MemoryRepository:
    def __init__(self) -> None:
        self._items: dict[int, PrioritySuggestion] = {}

    def get(self, entity_id: int) -> PrioritySuggestion | None:
        return self._items.get(entity_id)

    def save(self, entity: PrioritySuggestion) -> None:
        self._items[entity.id] = entity


def mark_reviewed(
    repository: Repository[PrioritySuggestion], suggestion_id: int
) -> PrioritySuggestion:
    suggestion = repository.get(suggestion_id)
    if suggestion is None:
        raise LookupError(suggestion_id)
    reviewed = PrioritySuggestion(
        id=suggestion.id,
        order_id=suggestion.order_id,
        level=suggestion.level,
        reviewed=True,
    )
    repository.save(reviewed)
    return reviewed
