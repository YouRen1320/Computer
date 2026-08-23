"""Public exercise: complete the fail-closed restore-target policy."""


def restore_allowed(*, environment: str, target_empty: bool, key_separated: bool) -> bool:
    # Deliberately incomplete: this currently ignores production and key location.
    return target_empty
