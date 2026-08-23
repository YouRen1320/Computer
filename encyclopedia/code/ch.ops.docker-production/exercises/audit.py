"""Public exercise: detect mutable tags and copied secrets."""


def audit(dockerfile: str, context_files: list[str]) -> list[str]:
    errors: list[str] = []
    # Deliberately incomplete: this only checks that a USER instruction exists.
    if "USER " not in dockerfile:
        errors.append("USER is required")
    return errors
