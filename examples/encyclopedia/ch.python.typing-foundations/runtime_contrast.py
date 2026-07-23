"""Annotations are metadata, not automatic runtime validation."""


def identity_count(count: int) -> int:
    return count


# This file is intentionally executed but excluded from the green type-check target.
result = identity_count("three")  # type: ignore[arg-type]
print(f"value={result},runtime_type={type(result).__name__}")
