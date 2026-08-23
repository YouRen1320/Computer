"""Dependency-free distance functions and exact retrieval."""

from __future__ import annotations

from dataclasses import dataclass
import math


Vector = tuple[float, ...]


def _pair(left: Vector, right: Vector) -> None:
    if not left or len(left) != len(right):
        raise ValueError("vectors must be non-empty and have equal dimensions")


def l2_distance(left: Vector, right: Vector) -> float:
    _pair(left, right)
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right, strict=True)))


def inner_product(left: Vector, right: Vector) -> float:
    _pair(left, right)
    return sum(a * b for a, b in zip(left, right, strict=True))


def cosine_distance(left: Vector, right: Vector) -> float:
    _pair(left, right)
    left_norm = math.sqrt(inner_product(left, left))
    right_norm = math.sqrt(inner_product(right, right))
    if left_norm == 0 or right_norm == 0:
        raise ValueError("cosine distance is undefined for a zero vector")
    return 1 - inner_product(left, right) / (left_norm * right_norm)


@dataclass(frozen=True)
class EmbeddedChunk:
    chunk_id: str
    space_id: str
    vector: Vector


def exact_cosine_search(rows: list[EmbeddedChunk], query: Vector, space_id: str, limit: int) -> list[tuple[str, float]]:
    if limit < 1:
        raise ValueError("limit must be positive")
    compatible = [row for row in rows if row.space_id == space_id]
    if any(len(row.vector) != len(query) for row in compatible):
        raise ValueError("query and stored vectors use incompatible dimensions")
    scored = [(row.chunk_id, cosine_distance(row.vector, query)) for row in compatible]
    return sorted(scored, key=lambda item: (item[1], item[0]))[:limit]
