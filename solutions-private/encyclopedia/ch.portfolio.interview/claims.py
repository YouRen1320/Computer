"""Reference solution for truthful, evidence-backed portfolio claims."""


def is_publishable(claim: dict) -> bool:
    if not claim.get("text") or not claim.get("evidence"):
        return False
    if claim.get("project_kind") == "employment" and not claim.get("verifiable_dates"):
        return False
    if (claim.get("ai_assisted") or claim.get("team")) and claim.get("ownership") == "independent":
        return False
    if claim.get("production") and claim.get("verification_level") != "reviewed":
        return False
    return True
