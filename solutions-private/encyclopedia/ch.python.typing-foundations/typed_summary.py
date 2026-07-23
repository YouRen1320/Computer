"""Private solution with narrowed unions and precise values."""


def display_name(name: str | None) -> str:
    if name is None:
        return "未命名"
    return name.upper()


def collect_priorities() -> list[int]:
    result: list[int] = [1, 2]
    result.append(4)
    return result


def count_active() -> int:
    return 2
