"""Five-document lexical retrieval lab."""

from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass
import math
import re


TOKEN_PATTERN = re.compile(r"[a-z0-9]+")


def tokenize(text: str) -> list[str]:
    return TOKEN_PATTERN.findall(text.casefold())


@dataclass(frozen=True)
class Hit:
    doc_id: str
    score: float
    contributions: tuple[tuple[str, int, int, float], ...]


class BM25Index:
    def __init__(self, documents: dict[str, str], *, k1: float = 1.2, b: float = 0.75) -> None:
        if not documents or k1 <= 0 or not 0 <= b <= 1:
            raise ValueError("invalid corpus or BM25 parameters")
        self.k1, self.b = k1, b
        self.terms = {doc_id: tokenize(text) for doc_id, text in documents.items()}
        self.lengths = {doc_id: len(tokens) for doc_id, tokens in self.terms.items()}
        if any(length == 0 for length in self.lengths.values()):
            raise ValueError("empty normalized document")
        self.n = len(documents)
        self.avgdl = sum(self.lengths.values()) / self.n
        postings: dict[str, dict[str, int]] = defaultdict(dict)
        for doc_id, tokens in self.terms.items():
            for term, tf in Counter(tokens).items():
                postings[term][doc_id] = tf
        self.postings = {term: dict(rows) for term, rows in postings.items()}

    def _idf(self, term: str) -> float:
        df = len(self.postings.get(term, {}))
        return math.log(1 + (self.n - df + 0.5) / (df + 0.5))

    def search(self, query: str, limit: int = 5) -> list[Hit]:
        if limit <= 0:
            raise ValueError("limit must be positive")
        query_terms = list(dict.fromkeys(tokenize(query)))
        hits: list[Hit] = []
        for doc_id in self.terms:
            pieces: list[tuple[str, int, int, float]] = []
            score = 0.0
            for term in query_terms:
                posting = self.postings.get(term, {})
                tf = posting.get(doc_id, 0)
                if not tf:
                    continue
                df = len(posting)
                norm = self.k1 * (1 - self.b + self.b * self.lengths[doc_id] / self.avgdl)
                contribution = self._idf(term) * tf * (self.k1 + 1) / (tf + norm)
                pieces.append((term, tf, df, contribution))
                score += contribution
            hits.append(Hit(doc_id, score, tuple(pieces)))
        return sorted(hits, key=lambda hit: (-hit.score, hit.doc_id))[:limit]
