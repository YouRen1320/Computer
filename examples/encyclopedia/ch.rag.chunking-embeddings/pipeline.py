import hashlib
from dataclasses import dataclass


@dataclass(frozen=True)
class Document:
    document_id: str
    document_hash: str
    title: str
    paragraphs: tuple[str, ...]
    acl: tuple[str, ...]


def chunk(document: Document, max_chars: int) -> list[dict[str, object]]:
    chunks: list[dict[str, object]] = []
    for ordinal, paragraph in enumerate(document.paragraphs):
        if len(paragraph) > max_chars:
            raise ValueError("paragraph exceeds toy hard limit")
        text = f"{document.title}\n{paragraph}"
        digest = hashlib.sha256(text.encode()).hexdigest()
        chunks.append(
            {
                "chunk_id": f"{document.document_id}:{ordinal}:{digest[:10]}",
                "parent_id": document.document_id,
                "parent_hash": document.document_hash,
                "ordinal": ordinal,
                "text": text,
                "acl": document.acl,
                "input_hash": digest,
            }
        )
    return chunks


def mock_embed(text: str, dimension: int = 4) -> list[float]:
    raw = hashlib.sha256(text.encode()).digest()
    return [raw[index] / 255 for index in range(dimension)]
