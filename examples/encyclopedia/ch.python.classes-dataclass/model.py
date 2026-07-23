from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum, unique


@unique
class SuggestionStatus(StrEnum):
    DRAFT = "DRAFT"
    REVIEWED = "REVIEWED"
    REJECTED = "REJECTED"


@dataclass(frozen=True, slots=True, kw_only=True)
class PrioritySuggestion:
    order_id: str
    level: int
    reasons: tuple[str, ...] = field(default_factory=tuple)
    status: SuggestionStatus = SuggestionStatus.DRAFT

    def __post_init__(self) -> None:
        if not self.order_id.startswith("WO-"):
            raise ValueError("invalid work-order id")
        if not 1 <= self.level <= 5:
            raise ValueError("level must be between 1 and 5")
        normalized = tuple(" ".join(reason.split()) for reason in self.reasons)
        if any(not reason for reason in normalized):
            raise ValueError("reasons must not contain blank values")
        object.__setattr__(self, "reasons", normalized)


@dataclass
class ReviewQueue:
    items: list[str] = field(default_factory=list)


class PriorityPolicy:
    def score(self, severity: int, safety_risk: bool) -> int:
        if not 1 <= severity <= 5:
            raise ValueError("severity must be between 1 and 5")
        return min(5, severity + int(safety_risk))


class SuggestionService:
    def __init__(self, policy: PriorityPolicy) -> None:
        self._policy = policy

    def suggest(
        self,
        *,
        order_id: str,
        severity: int,
        safety_risk: bool,
    ) -> PrioritySuggestion:
        level = self._policy.score(severity, safety_risk)
        reason = "safety risk" if safety_risk else "reported severity"
        return PrioritySuggestion(order_id=order_id, level=level, reasons=(reason,))
