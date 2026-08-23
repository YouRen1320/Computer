from dataclasses import dataclass


@dataclass(frozen=True)
class Document:
    source_id: str
    tenant_id: str
    text: str


def candidates_for_model(tenant_id: str, documents: tuple[Document, ...]) -> tuple[Document, ...]:
    # TODO: enforce tenant/ACL before any candidate reaches ranking or model context.
    ranked = tuple(sorted(documents, key=lambda item: item.source_id))
    return ranked
