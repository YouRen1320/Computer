"""Reference solution for an all-required-jobs release gate."""


def may_release(results: dict[str, str], required: set[str]) -> bool:
    return bool(required) and all(results.get(name) == "success" for name in required)
