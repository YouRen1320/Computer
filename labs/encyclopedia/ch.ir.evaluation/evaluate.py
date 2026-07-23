"""Frozen-query evaluation with per-query evidence."""

from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass

import pandas as pd


@dataclass(frozen=True)
class QueryCase:
    query_id: str
    text: str
    ranking: tuple[str, ...]
    grades: dict[str, int]
    slice_name: str


def dataset_hash(cases: tuple[QueryCase, ...]) -> str:
    payload = [
        {
            "grades": dict(sorted(case.grades.items())),
            "query_id": case.query_id,
            "slice_name": case.slice_name,
            "text": case.text,
        }
        for case in sorted(cases, key=lambda item: item.query_id)
    ]
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def evaluate_case(case: QueryCase, k: int = 3) -> dict[str, object]:
    if k < 1 or len(set(case.ranking)) != len(case.ranking):
        raise ValueError("invalid k or duplicate ranking")
    relevant = [doc_id for doc_id, grade in case.grades.items() if grade > 0]
    if not relevant:
        raise ValueError(f"{case.query_id} has no positive relevance judgment")
    top = case.ranking[:k]
    hits = [doc_id for doc_id in top if case.grades.get(doc_id, 0) > 0]
    first = next((rank for rank, doc_id in enumerate(case.ranking, 1) if case.grades.get(doc_id, 0) > 0), None)
    dcg = sum((2 ** case.grades.get(doc_id, 0) - 1) / math.log2(rank + 1) for rank, doc_id in enumerate(top, 1))
    ideals = sorted((grade for grade in case.grades.values() if grade > 0), reverse=True)[:k]
    idcg = sum((2**grade - 1) / math.log2(rank + 1) for rank, grade in enumerate(ideals, 1))
    unjudged = [doc_id for doc_id in top if doc_id not in case.grades]
    return {
        "query_id": case.query_id,
        "slice": case.slice_name,
        "precision_at_3": len(hits) / k,
        "recall_at_3": len(hits) / len(relevant),
        "mrr": 0 if first is None else 1 / first,
        "ndcg_at_3": 0 if idcg == 0 else dcg / idcg,
        "unjudged_top_k": tuple(unjudged),
        "ranking": case.ranking,
    }


def report(cases: tuple[QueryCase, ...]) -> pd.DataFrame:
    return pd.DataFrame([evaluate_case(case) for case in cases]).sort_values("query_id").reset_index(drop=True)
