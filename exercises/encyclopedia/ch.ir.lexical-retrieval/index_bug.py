"""Intentionally broken document-frequency implementation."""

from collections import Counter
import re


def tokenize(text: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", text.casefold())


def document_frequency(documents: dict[str, str], term: str) -> int:
    # BUG: this is collection frequency, so repetition inside one document inflates df.
    return sum(Counter(tokenize(text))[term] for text in documents.values())
