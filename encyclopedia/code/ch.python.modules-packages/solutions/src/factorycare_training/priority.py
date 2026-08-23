def normalize_priority(value: int) -> int:
    if not 1 <= value <= 5:
        raise ValueError("priority must be between 1 and 5")
    return value
