"""Lazy generator and metadata-preserving decorator."""

from __future__ import annotations

from collections.abc import Callable, Iterator
from functools import wraps
from typing import ParamSpec, TypeVar


P = ParamSpec("P")
R = TypeVar("R")


def active(values: list[str], trace: list[str]) -> Iterator[str]:
    trace.append("started")
    for value in values:
        trace.append(f"seen:{value}")
        if value != "CLOSED":
            yield value
    trace.append("finished")


def transparent(function: Callable[P, R]) -> Callable[P, R]:
    @wraps(function)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        return function(*args, **kwargs)

    return wrapper


@transparent
def label(order_id: int, *, status: str) -> str:
    """Render an order label."""
    if order_id < 0:
        raise ValueError("negative id")
    return f"{order_id}:{status}"
