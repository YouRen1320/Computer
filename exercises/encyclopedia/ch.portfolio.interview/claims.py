"""Public exercise: deliberately accepts polished text without evidence."""


def is_publishable(claim: dict) -> bool:
    # Deliberately wrong: wording length cannot prove dates, ownership or verification.
    return len(claim.get("text", "")) >= 10
