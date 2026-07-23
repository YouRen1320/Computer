"""Correct document-frequency implementation."""

import re


def tokenize(text: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", text.casefold())


def document_frequency(documents: dict[str, str], term: str) -> int:
    normalized = term.casefold()
    return sum(normalized in set(tokenize(text)) for text in documents.values())
