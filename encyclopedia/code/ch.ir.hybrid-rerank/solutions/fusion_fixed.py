"""Scale-invariant reciprocal rank fusion from source scores."""

from collections import defaultdict


def fuse(sparse: dict[str, float], dense: dict[str, float], rank_constant: int = 60) -> list[str]:
    totals: dict[str, float] = defaultdict(float)
    for scores in (sparse, dense):
        ranking = sorted(scores, key=lambda doc_id: (-scores[doc_id], doc_id))
        for rank, doc_id in enumerate(ranking, 1):
            totals[doc_id] += 1 / (rank_constant + rank)
    return sorted(totals, key=lambda doc_id: (-totals[doc_id], doc_id))
