from collections.abc import Sequence


def conditional_probability(event: Sequence[bool], condition: Sequence[bool]) -> float:
    if len(event) != len(condition):
        raise ValueError("event and condition lengths differ")
    denominator = sum(bool(value) for value in condition)
    if denominator == 0:
        raise ValueError("condition has no outcomes")
    numerator = sum(bool(e) and bool(c) for e, c in zip(event, condition, strict=True))
    return numerator / denominator
