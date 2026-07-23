"""Classify the earliest failed network layer from explicit probe evidence."""

from dataclasses import dataclass


@dataclass(frozen=True)
class ProbeEvidence:
    dns_ok: bool
    tcp_ok: bool
    tls_ok: bool
    http_status: int | None


def earliest_failure(evidence: ProbeEvidence) -> str:
    if not evidence.dns_ok:
        return "dns"
    if not evidence.tcp_ok:
        return "tcp"
    if not evidence.tls_ok:
        return "tls"
    if evidence.http_status is None:
        return "http-no-response"
    if evidence.http_status >= 500:
        return "http-upstream"
    if evidence.http_status >= 400:
        return "http-request"
    return "none"
