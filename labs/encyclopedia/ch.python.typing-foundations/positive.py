"""Positive fixture: object boundaries are narrowed before use."""

type OrderId = str
type Counts = dict[str, int]


def normalize_order_id(raw: object) -> OrderId:
    if isinstance(raw, int):
        return f"WO-{raw:06d}"
    if isinstance(raw, str):
        return raw.strip()
    raise TypeError("order id must be int or str")


def uppercase_or_empty(value: str | None) -> str:
    if value is None:
        return ""
    return value.upper()


def count(values: list[str]) -> Counts:
    result: Counts = {}
    for value in values:
        result[value] = result.get(value, 0) + 1
    return result
