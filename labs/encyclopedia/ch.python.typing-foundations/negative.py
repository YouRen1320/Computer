"""Negative fixture: every line below violates a declared contract."""


def total(values: list[int]) -> int:
    return sum(values)


def uppercase(value: str | None) -> str:
    return value.upper()


def wrong_return() -> int:
    return "not-an-int"


bad_total: int = total([1, "2"])
