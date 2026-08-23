"""nDCG with an independent ideal ranking."""

import math


def ndcg(ranking: list[str], grades: dict[str, int], k: int) -> float:
    if k < 1:
        raise ValueError("k must be positive")
    dcg = sum((2 ** grades.get(doc_id, 0) - 1) / math.log2(rank + 1) for rank, doc_id in enumerate(ranking[:k], 1))
    ideal_grades = sorted((grade for grade in grades.values() if grade > 0), reverse=True)[:k]
    idcg = sum((2**grade - 1) / math.log2(rank + 1) for rank, grade in enumerate(ideal_grades, 1))
    return dcg / idcg if idcg else 0.0
