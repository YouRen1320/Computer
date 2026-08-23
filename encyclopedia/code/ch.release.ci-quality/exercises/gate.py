"""Public exercise: make release require every named job to succeed."""


def may_release(results: dict[str, str], required: set[str]) -> bool:
    # Deliberately wrong: one passing job cannot satisfy the whole gate.
    return any(results.get(name) == "success" for name in required)
