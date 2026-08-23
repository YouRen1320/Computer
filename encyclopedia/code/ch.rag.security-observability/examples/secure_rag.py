from __future__ import annotations

import hashlib
from dataclasses import dataclass, field


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


@dataclass(frozen=True)
class CacheScope:
    """Every version that can change which evidence or answer is reusable."""

    permission_version: str
    visible_resource_ids: frozenset[str]
    index_version: str
    model_version: str
    prompt_version: str


@dataclass
class Trace:
    events: list[dict[str, object]] = field(default_factory=list)
    counters: dict[str, int] = field(default_factory=dict)

    _ALLOWLIST = {
        "retrieval": frozenset({
            "tenant_ref", "subject_ref", "query_length", "query_sha256",
            "query_class", "candidate_count", "selected_count", "index_version",
            "permission_version",
        }),
        "security.prompt_injection_signal": frozenset({
            "tenant_ref", "resource_ref", "signal_count", "permission_version",
        }),
    }

    def emit(self, name: str, **attributes: object) -> None:
        """Admit only event-specific fields; arbitrary text never becomes telemetry."""
        allowed = self._ALLOWLIST.get(name)
        if allowed is None:
            raise ValueError(f"trace event is not registered: {name}")
        unknown = set(attributes) - allowed
        if unknown:
            raise ValueError(f"trace attributes are not allowlisted: {sorted(unknown)}")
        self.events.append({"name": name, "attributes": dict(attributes)})
        self.counters[name] = self.counters.get(name, 0) + 1


def opaque_ref(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()[:16]


def summarize_query(query: str) -> dict[str, str | int]:
    normalized = " ".join(query.split())
    return {
        "query_length": len(query),
        "query_sha256": hashlib.sha256(normalized.encode()).hexdigest(),
        "query_class": "empty" if not normalized else "free-text",
    }


def cache_key(principal: Principal, query: str, scope: CacheScope) -> str:
    visible_resource_digest = hashlib.sha256(
        "\x00".join(sorted(scope.visible_resource_ids)).encode()
    ).hexdigest()
    material = "|".join(
        [
            principal.tenant_id,
            principal.subject_id,
            ",".join(sorted(principal.roles)),
            scope.permission_version,
            visible_resource_digest,
            scope.index_version,
            scope.model_version,
            scope.prompt_version,
            hashlib.sha256(query.encode()).hexdigest(),
        ]
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
    scope: CacheScope,
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
        tenant_ref=opaque_ref(principal.tenant_id),
        subject_ref=opaque_ref(principal.subject_id),
        **summarize_query(query),
        candidate_count=len(authorized),
        selected_count=len(selected),
        index_version=scope.index_version,
        permission_version=scope.permission_version,
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
    scope: CacheScope,
) -> dict[str, object]:
    selected = retrieve(principal, documents, query, trace, scope)
    for document in selected:
        signals = injection_signals(document)
        if signals:
            trace.emit(
                "security.prompt_injection_signal",
                tenant_ref=opaque_ref(principal.tenant_id),
                resource_ref=opaque_ref(document.source_id),
                signal_count=len(signals),
                permission_version=scope.permission_version,
            )
    return {
        "answer": generator.answer(selected),
        "source_ids": [document.source_id for document in selected],
        "cache_key": cache_key(principal, query, scope),
    }
