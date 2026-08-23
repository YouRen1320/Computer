from repaired.common import DEFAULT_ASSIGNEE
from repaired.rendering import render


def assign() -> str:
    return render(DEFAULT_ASSIGNEE)
