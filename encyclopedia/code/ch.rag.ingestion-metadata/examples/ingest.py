import hashlib
from dataclasses import dataclass


@dataclass(frozen=True)
class Source:
    document_id: str
    source_uri: str
    source_version: str
    acl: tuple[str, ...]
    text: str


def normalize(text: str) -> str:
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    return "\n".join(line.rstrip() for line in lines).strip() + "\n"


def ingest(source: Source) -> dict[str, object]:
    if not source.source_uri or not source.source_version or not source.acl:
        raise ValueError("source URI, version and ACL are required")
    normalized = normalize(source.text)
    return {
        "document_id": source.document_id,
        "source_uri": source.source_uri,
        "source_version": source.source_version,
        "acl": source.acl,
        "normalized_text": normalized,
        "normalized_hash": hashlib.sha256(normalized.encode("utf-8")).hexdigest(),
        "normalizer_id": "lf-rstrip-v1",
    }
