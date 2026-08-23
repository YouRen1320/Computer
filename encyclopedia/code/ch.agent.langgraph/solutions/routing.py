def approval_route(decision: str) -> str:
    if decision == "approve":
        return "execute"
    if decision in {"reject", "timeout", "cancel"}:
        return "terminate"
    raise ValueError("unknown decision")
