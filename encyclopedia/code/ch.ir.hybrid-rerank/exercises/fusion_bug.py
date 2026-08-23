"""Intentionally broken raw-score fusion."""


def fuse(sparse: dict[str, float], dense: dict[str, float]) -> list[str]:
    documents = set(sparse) | set(dense)
    # BUG: BM25 and cosine scores do not share a calibrated numeric scale.
    return sorted(documents, key=lambda doc_id: (-(sparse.get(doc_id, 0) + dense.get(doc_id, 0)), doc_id))
