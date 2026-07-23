from dataclasses import dataclass, field


@dataclass
class IdempotentAuthority:
    receipts: dict[str, str] = field(default_factory=dict)
    writes: int = 0

    def write(self, key: str) -> str:
        if key not in self.receipts:
            self.receipts[key] = f"receipt:{key}"
            self.writes += 1
        return self.receipts[key]


def require_state_version(state: dict[str, object]) -> None:
    if state.get("schema_version") != 1:
        raise ValueError("unsupported state version")


def approval_route(decision: str) -> str:
    if decision == "approve":
        return "execute"
    if decision in {"reject", "timeout", "cancel"}:
        return "terminate"
    raise ValueError("unknown approval decision")


def bounded_retry(success_on: int | None, budget: int) -> tuple[str, int]:
    for attempt in range(1, budget + 1):
        if success_on == attempt:
            return "succeeded", attempt
    return "budget_exhausted", budget
