"""Controlled four-way ablation for hybrid retrieval plumbing."""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
import math

import pandas as pd


@dataclass(frozen=True)
class Case:
    query_id: str
    grades: dict[str, int]
    sparse: tuple[str, ...]
    dense: tuple[str, ...]
    reranker_scores: dict[str, float]
    allowed_doc_ids: frozenset[str]


def rrf(rankings: tuple[tuple[str, ...], ...], allowed: frozenset[str], rank_constant: int = 60) -> tuple[str, ...]:
    scores: dict[str, float] = defaultdict(float)
    for ranking in rankings:
        if len(set(ranking)) != len(ranking):
            raise ValueError("source ranking contains duplicates")
        authorized = [doc_id for doc_id in ranking if doc_id in allowed]
        for rank, doc_id in enumerate(authorized, 1):
            scores[doc_id] += 1 / (rank_constant + rank)
    return tuple(sorted(scores, key=lambda doc_id: (-scores[doc_id], doc_id)))


def rerank(candidates: tuple[str, ...], scores: dict[str, float], allowed: frozenset[str], depth: int) -> tuple[str, ...]:
    if depth < 1:
        raise ValueError("depth must be positive")
    authorized = tuple(doc_id for doc_id in candidates if doc_id in allowed)
    head = authorized[:depth]
    tail = authorized[depth:]
    return tuple(sorted(head, key=lambda doc_id: (-scores.get(doc_id, float("-inf")), doc_id))) + tail


def ndcg_at_3(ranking: tuple[str, ...], grades: dict[str, int]) -> float:
    dcg = sum((2 ** grades.get(doc_id, 0) - 1) / math.log2(rank + 1) for rank, doc_id in enumerate(ranking[:3], 1))
    ideals = sorted((grade for grade in grades.values() if grade > 0), reverse=True)[:3]
    idcg = sum((2**grade - 1) / math.log2(rank + 1) for rank, grade in enumerate(ideals, 1))
    return dcg / idcg if idcg else 0.0


def ablation(cases: tuple[Case, ...], latency_fixture_ms: dict[str, int], budget_ms: int) -> pd.DataFrame:
    rows: list[dict[str, object]] = []
    for case in cases:
        sparse = tuple(doc_id for doc_id in case.sparse if doc_id in case.allowed_doc_ids)
        dense = tuple(doc_id for doc_id in case.dense if doc_id in case.allowed_doc_ids)
        hybrid = rrf((case.sparse, case.dense), case.allowed_doc_ids)
        ranked = rerank(hybrid, case.reranker_scores, case.allowed_doc_ids, depth=3)
        for method, result in (("sparse", sparse), ("dense", dense), ("hybrid", hybrid), ("rerank", ranked)):
            rows.append(
                {
                    "query_id": case.query_id,
                    "method": method,
                    "ranking": result,
                    "ndcg_at_3": ndcg_at_3(result, case.grades),
                    "latency_fixture_ms": latency_fixture_ms[method],
                    "within_budget": latency_fixture_ms[method] <= budget_ms,
                    "measurement_kind": "controlled_budget_fixture_not_wall_clock",
                }
            )
    return pd.DataFrame(rows)
