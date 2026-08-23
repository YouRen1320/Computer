"""A small, auditable inverted index and BM25 implementation."""

from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass
import math
import re


TOKEN_PATTERN = re.compile(r"[a-z0-9]+")


def tokenize(text: str) -> list[str]:
    """Apply one deterministic normalization contract to documents and queries."""
    return TOKEN_PATTERN.findall(text.casefold())


@dataclass(frozen=True)
class ScorePart:
    term: str
    tf: int
    df: int
    idf: float
    saturation: float
    contribution: float


class InvertedIndex:
    def __init__(self, documents: dict[str, str]) -> None:
        if not documents:
            raise ValueError("documents must not be empty")
        self.documents = dict(documents)
        self.tokens = {doc_id: tokenize(text) for doc_id, text in documents.items()}
        if any(not terms for terms in self.tokens.values()):
            raise ValueError("every document must contain at least one token")
        postings: dict[str, dict[str, int]] = defaultdict(dict)
        for doc_id, terms in self.tokens.items():
            for term, frequency in Counter(terms).items():
                postings[term][doc_id] = frequency
        self.postings = {term: dict(rows) for term, rows in postings.items()}
        self.lengths = {doc_id: len(terms) for doc_id, terms in self.tokens.items()}
        self.document_count = len(documents)
        self.average_length = sum(self.lengths.values()) / self.document_count

    def document_frequency(self, term: str) -> int:
        return len(self.postings.get(term, {}))

    def inverse_document_frequency(self, term: str) -> float:
        df = self.document_frequency(term)
        return math.log(1.0 + (self.document_count - df + 0.5) / (df + 0.5))

    def explain(self, query: str, doc_id: str, *, k1: float = 1.2, b: float = 0.75) -> list[ScorePart]:
        if doc_id not in self.documents:
            raise KeyError(doc_id)
        if k1 <= 0 or not 0 <= b <= 1:
            raise ValueError("k1 must be positive and b must be between zero and one")
        # This course contract treats repeated query tokens as one retrieval term.
        terms = list(dict.fromkeys(tokenize(query)))
        parts: list[ScorePart] = []
        for term in terms:
            tf = self.postings.get(term, {}).get(doc_id, 0)
            if tf == 0:
                continue
            df = self.document_frequency(term)
            idf = self.inverse_document_frequency(term)
            length_ratio = self.lengths[doc_id] / self.average_length
            denominator = tf + k1 * (1 - b + b * length_ratio)
            saturation = tf * (k1 + 1) / denominator
            parts.append(ScorePart(term, tf, df, idf, saturation, idf * saturation))
        return parts

    def score(self, query: str, doc_id: str) -> float:
        return sum(part.contribution for part in self.explain(query, doc_id))

    def search(self, query: str, *, limit: int = 10) -> list[tuple[str, float]]:
        if limit < 1:
            raise ValueError("limit must be positive")
        scored = [(doc_id, self.score(query, doc_id)) for doc_id in self.documents]
        return sorted(scored, key=lambda row: (-row[1], row[0]))[:limit]
