"""Small ranking metrics with explicit edge-case contracts."""

from __future__ import annotations

import math
from collections.abc import Mapping, Sequence


def _validate(ranking: Sequence[str], k: int) -> None:
    if k < 1:
        raise ValueError("k must be positive")
    if len(set(ranking)) != len(ranking):
        raise ValueError("ranking must not contain duplicate document ids")


def precision_at_k(ranking: Sequence[str], grades: Mapping[str, int], k: int) -> float:
    _validate(ranking, k)
    hits = sum(grades.get(doc_id, 0) > 0 for doc_id in ranking[:k])
    return hits / k


def recall_at_k(ranking: Sequence[str], grades: Mapping[str, int], k: int) -> float:
    _validate(ranking, k)
    relevant = sum(grade > 0 for grade in grades.values())
    if relevant == 0:
        raise ValueError("recall is undefined without a relevant judgment")
    hits = sum(grades.get(doc_id, 0) > 0 for doc_id in ranking[:k])
    return hits / relevant


def reciprocal_rank(ranking: Sequence[str], grades: Mapping[str, int]) -> float:
    _validate(ranking, 1)
    for rank, doc_id in enumerate(ranking, start=1):
        if grades.get(doc_id, 0) > 0:
            return 1 / rank
    return 0.0


def dcg_at_k(ranking: Sequence[str], grades: Mapping[str, int], k: int) -> float:
    _validate(ranking, k)
    return sum(
        (2 ** grades.get(doc_id, 0) - 1) / math.log2(rank + 1)
        for rank, doc_id in enumerate(ranking[:k], start=1)
    )


def ndcg_at_k(ranking: Sequence[str], grades: Mapping[str, int], k: int) -> float:
    actual = dcg_at_k(ranking, grades, k)
    ideal_grades = sorted((grade for grade in grades.values() if grade > 0), reverse=True)
    ideal = sum((2**grade - 1) / math.log2(rank + 1) for rank, grade in enumerate(ideal_grades[:k], start=1))
    return actual / ideal if ideal else 0.0
