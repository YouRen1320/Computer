"""Public exercise with intentional static type errors."""


def display_name(name: str | None) -> str:
    return name.upper()


def collect_priorities() -> list[int]:
    result: list[int] = [1, 2]
    result.append("urgent")
    return result


def count_active() -> int:
    return "2"
