from dataclasses import dataclass


@dataclass(frozen=True, slots=True, kw_only=True)
class PrioritySuggestion:
    order_id: str
    level: int

    def __post_init__(self) -> None:
        if not self.order_id.startswith("WO-"):
            raise ValueError("invalid work-order id")
        if not 1 <= self.level <= 5:
            raise ValueError("level must be between 1 and 5")
