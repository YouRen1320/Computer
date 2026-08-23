def sum_one_through(n: int) -> int:
    if n < 0:
        raise ValueError("n must be non-negative")
    return sum(range(1, n + 1))
