from dataclasses import dataclass


@dataclass(frozen=True)
class Document:
    source_id: str
    tenant_id: str
    text: str


def candidates_for_model(tenant_id: str, documents: tuple[Document, ...]) -> tuple[Document, ...]:
    authorized = tuple(item for item in documents if item.tenant_id == tenant_id)
    return tuple(sorted(authorized, key=lambda item: item.source_id))
