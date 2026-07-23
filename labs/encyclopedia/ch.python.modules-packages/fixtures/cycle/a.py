from cycle.b import render

DEFAULT_ASSIGNEE = "tech-7"


def assign() -> str:
    return render(DEFAULT_ASSIGNEE)
