"""Intentionally broken nDCG: the denominator copies the system ranking."""

import math


def ndcg(ranking: list[str], grades: dict[str, int], k: int) -> float:
    dcg = sum((2 ** grades.get(doc_id, 0) - 1) / math.log2(rank + 1) for rank, doc_id in enumerate(ranking[:k], 1))
    # BUG: an ideal ranking must sort grades independently of the tested system.
    idcg = sum((2 ** grades.get(doc_id, 0) - 1) / math.log2(rank + 1) for rank, doc_id in enumerate(ranking[:k], 1))
    return dcg / idcg if idcg else 0.0
