import hashlib
from dataclasses import dataclass


@dataclass(frozen=True)
class InputDocument:
    document_id: str
    source_uri: str
    source_version: str
    media_type: str
    acl: tuple[str, ...]
    extracted_text: str | None


def run(documents: list[InputDocument]) -> tuple[list[dict[str, object]], list[dict[str, str]]]:
    published: list[dict[str, object]] = []
    quarantine: list[dict[str, str]] = []
    for item in documents:
        try:
            if not item.acl:
                raise ValueError("missing_acl")
            if item.extracted_text is None:
                raise ValueError("parse_failed")
            text = item.extracted_text.replace("\r\n", "\n").strip() + "\n"
            published.append(
                {
                    "document_id": item.document_id,
                    "source_uri": item.source_uri,
                    "source_version": item.source_version,
                    "media_type": item.media_type,
                    "acl": item.acl,
                    "text": text,
                    "hash": hashlib.sha256(text.encode()).hexdigest(),
                    "lineage": "fixture-parser-v1",
                }
            )
        except ValueError as error:
            quarantine.append(
                {
                    "document_id": item.document_id,
                    "source_uri": item.source_uri,
                    "source_version": item.source_version,
                    "stage": "validate_or_parse",
                    "error": str(error),
                }
            )
    return published, quarantine
