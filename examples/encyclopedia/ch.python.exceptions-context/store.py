"""Exception translation and context-manager cleanup example."""

from __future__ import annotations

import json
from dataclasses import dataclass


class CorruptRepositoryData(Exception):
    """The repository payload cannot be decoded."""


@dataclass
class TrackedResource:
    text: str
    entered: int = 0
    exited: int = 0

    def __enter__(self) -> "TrackedResource":
        self.entered += 1
        return self

    def __exit__(self, exc_type, exc, traceback) -> bool:
        self.exited += 1
        return False

    def read(self) -> str:
        return self.text


def load(resource: TrackedResource) -> list[dict[str, object]]:
    with resource as stream:
        try:
            payload = json.loads(stream.read())
        except json.JSONDecodeError as error:
            raise CorruptRepositoryData("invalid work-order JSON") from error
    if not isinstance(payload, list):
        raise CorruptRepositoryData("work-order root must be a list")
    return payload
