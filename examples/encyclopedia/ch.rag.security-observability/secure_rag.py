from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field


EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
PHONE = re.compile(r"(?<!\d)1[3-9]\d{9}(?!\d)")


@dataclass(frozen=True)
class Principal:
    subject_id: str
    tenant_id: str
    roles: frozenset[str]


@dataclass(frozen=True)
class Document:
    source_id: str
    tenant_id: str
    allowed_roles: frozenset[str]
    text: str


@dataclass
class Trace:
    events: list[dict[str, object]] = field(default_factory=list)
    counters: dict[str, int] = field(default_factory=dict)

    def emit(self, name: str, **attributes: object) -> None:
        safe = {key: redact(str(value)) for key, value in attributes.items()}
        self.events.append({"name": name, "attributes": safe})
        self.counters[name] = self.counters.get(name, 0) + 1


def redact(value: str) -> str:
    return PHONE.sub("[PHONE]", EMAIL.sub("[EMAIL]", value))


def cache_key(principal: Principal, query: str) -> str:
    material = "|".join(
        [principal.tenant_id, principal.subject_id, *sorted(principal.roles), query]
    )
    return hashlib.sha256(material.encode()).hexdigest()


def authorized_candidates(
    principal: Principal,
    documents: tuple[Document, ...],
) -> tuple[Document, ...]:
    """Authorization is applied before ranking or context assembly."""
    return tuple(
        document
        for document in documents
        if document.tenant_id == principal.tenant_id
        and bool(document.allowed_roles & principal.roles)
    )


def retrieve(
    principal: Principal,
    documents: tuple[Document, ...],
    query: str,
    trace: Trace,
) -> tuple[Document, ...]:
    authorized = authorized_candidates(principal, documents)
    terms = set(query.lower().split())
    ranked = sorted(
        authorized,
        key=lambda item: sum(term in item.text.lower() for term in terms),
        reverse=True,
    )
    selected = tuple(ranked[:2])
    trace.emit(
        "retrieval",
        tenant_id=principal.tenant_id,
        subject_id=principal.subject_id,
        query=query,
        candidate_count=len(authorized),
        selected_ids=",".join(item.source_id for item in selected),
    )
    return selected


def injection_signals(document: Document) -> tuple[str, ...]:
    lowered = document.text.lower()
    markers = ("ignore previous", "system prompt", "调用写入工具", "泄露密钥")
    return tuple(marker for marker in markers if marker in lowered)


class ReadOnlyGeneratorFixture:
    """Captures exactly what enters the mock model; it cannot execute tools."""

    def __init__(self) -> None:
        self.seen_source_ids: tuple[str, ...] = ()

    def answer(self, documents: tuple[Document, ...]) -> str:
        self.seen_source_ids = tuple(item.source_id for item in documents)
        if not documents:
            return "证据不足。"
        return "已根据授权文档生成只读建议。"


def run_query(
    principal: Principal,
    documents: tuple[Document, ...],
    query: str,
    trace: Trace,
    generator: ReadOnlyGeneratorFixture,
) -> dict[str, object]:
    selected = retrieve(principal, documents, query, trace)
    for document in selected:
        signals = injection_signals(document)
        if signals:
            trace.emit(
                "security.prompt_injection_signal",
                tenant_id=principal.tenant_id,
                source_id=document.source_id,
                signal_count=len(signals),
            )
    return {
        "answer": generator.answer(selected),
        "source_ids": [document.source_id for document in selected],
        "cache_key": cache_key(principal, query),
    }
