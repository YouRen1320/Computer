"""Small function contracts for derived FactoryCare calculations."""


def calculate_total(unit_price_cents, quantity):
    """Return a cents total without accepting negative inputs."""
    if unit_price_cents < 0 or quantity < 0:
        raise ValueError("unit_price_cents and quantity must be non-negative")
    return unit_price_cents * quantity


def count_matching(values, predicate):
    """Return how many values satisfy a callable predicate."""
    count = 0
    for value in values:
        if predicate(value):
            count += 1
    return count


def is_urgent(priority):
    """Treat priorities four and five as urgent hints."""
    return priority >= 4


def with_hint(order, hint):
    """Return a new top-level record instead of mutating the input."""
    result = dict(order)
    result["hint"] = hint
    return result
