from collections.abc import Sequence


def conditional_probability(event: Sequence[bool], condition: Sequence[bool]) -> float:
    """TODO: compute P(event | condition), rejecting an empty condition."""
    both = sum(e and c for e, c in zip(event, condition, strict=True))
    # Deliberate fault: the denominator is the whole sample, not the condition count.
    return both / len(condition)
