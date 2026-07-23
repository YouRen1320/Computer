"""Generator cleanup trace for early and full consumption."""

from collections.abc import Iterator


def values(trace: list[str]) -> Iterator[int]:
    trace.append("open")
    try:
        for value in (1, 2, 3):
            trace.append(f"yield:{value}")
            yield value
    finally:
        trace.append("close")
