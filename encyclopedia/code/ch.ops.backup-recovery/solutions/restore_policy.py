"""Reference solution for the isolated restore-target gate."""


def restore_allowed(*, environment: str, target_empty: bool, key_separated: bool) -> bool:
    return environment.lower() not in {"prod", "production"} and target_empty and key_separated
