"""Reciprocal rank fusion with an explicit authorization input."""

from __future__ import annotations

from collections import defaultdict


def reciprocal_rank_fusion(
    rankings: dict[str, list[str]],
    *,
    allowed_doc_ids: set[str],
    rank_constant: int = 60,
) -> list[tuple[str, float, dict[str, int]]]:
    if rank_constant < 1:
        raise ValueError("rank_constant must be positive")
    totals: dict[str, float] = defaultdict(float)
    evidence: dict[str, dict[str, int]] = defaultdict(dict)
    for source, ranking in rankings.items():
        if len(set(ranking)) != len(ranking):
            raise ValueError(f"duplicate candidate in {source}")
        authorized = [doc_id for doc_id in ranking if doc_id in allowed_doc_ids]
        for rank, doc_id in enumerate(authorized, start=1):
            totals[doc_id] += 1 / (rank_constant + rank)
            evidence[doc_id][source] = rank
    ordered = sorted(totals, key=lambda doc_id: (-totals[doc_id], doc_id))
    return [(doc_id, totals[doc_id], evidence[doc_id]) for doc_id in ordered]
