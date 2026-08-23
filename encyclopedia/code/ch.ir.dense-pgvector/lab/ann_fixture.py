"""Controlled exact/approximate candidate fixture; not a database benchmark."""

from __future__ import annotations

from dataclasses import dataclass
import math


Vector = tuple[float, ...]


@dataclass(frozen=True)
class Row:
    chunk_id: str
    space_id: str
    vector: Vector


def cosine_distance(left: Vector, right: Vector) -> float:
    if not left or len(left) != len(right):
        raise ValueError("dimension mismatch")
    dot = sum(a * b for a, b in zip(left, right, strict=True))
    left_norm = math.sqrt(sum(value * value for value in left))
    right_norm = math.sqrt(sum(value * value for value in right))
    if left_norm == 0 or right_norm == 0:
        raise ValueError("zero vector")
    return 1 - dot / (left_norm * right_norm)


def rank(rows: list[Row], query: Vector, *, space_id: str, allowed_ids: set[str], limit: int) -> list[str]:
    candidates = [row for row in rows if row.space_id == space_id and row.chunk_id in allowed_ids]
    if any(len(row.vector) != len(query) for row in candidates):
        raise ValueError("embedding dimension mismatch")
    scored = [(row.chunk_id, cosine_distance(row.vector, query)) for row in candidates]
    return [doc_id for doc_id, _ in sorted(scored, key=lambda item: (item[1], item[0]))[:limit]]


def recall_at_k(exact: list[str], approximate: list[str], k: int) -> float:
    if k < 1 or len(exact) < k:
        raise ValueError("exact baseline must contain k results")
    return len(set(exact[:k]) & set(approximate[:k])) / k
