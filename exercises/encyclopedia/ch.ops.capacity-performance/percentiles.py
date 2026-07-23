"""Public exercise: implement nearest-rank percentile, not an average."""


def percentile(values: list[float], quantile: float) -> float:
    # Deliberately wrong: an average hides the tail.
    return sum(values) / len(values)
