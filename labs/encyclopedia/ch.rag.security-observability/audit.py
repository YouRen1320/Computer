import re
from dataclasses import dataclass


@dataclass(frozen=True)
class Candidate:
    source_id: str
    tenant_id: str


def audit_pre_model_candidates(tenant_id: str, candidates: tuple[Candidate, ...]) -> None:
    foreign = [item.source_id for item in candidates if item.tenant_id != tenant_id]
    if foreign:
        raise AssertionError(f"cross-tenant candidate reached model boundary: {foreign}")


def audit_trace(serialized_trace: str) -> None:
    if re.search(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", serialized_trace):
        raise AssertionError("raw email found in trace")
    if re.search(r"(?<!\d)1[3-9]\d{9}(?!\d)", serialized_trace):
        raise AssertionError("raw phone found in trace")


def audit_cache_key(parts: tuple[str, ...]) -> None:
    required = {"tenant_id", "subject_id", "roles", "query"}
    missing = required - set(parts)
    if missing:
        raise AssertionError(f"authorization dimensions missing from cache key: {sorted(missing)}")


def authorize_tool(system_prompt: str, server_permission: bool) -> bool:
    del system_prompt
    return server_permission
