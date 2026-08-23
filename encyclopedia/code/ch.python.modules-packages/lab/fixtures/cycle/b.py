from cycle.a import DEFAULT_ASSIGNEE


def render(name: str = DEFAULT_ASSIGNEE) -> str:
    return f"assigned to {name}"
