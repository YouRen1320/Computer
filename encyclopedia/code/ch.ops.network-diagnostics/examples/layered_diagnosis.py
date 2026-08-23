"""Classify the earliest failed network layer from explicit probe evidence."""

from dataclasses import dataclass


@dataclass(frozen=True)
class ProbeEvidence:
    dns_ok: bool
    tcp_ok: bool
    tls_ok: bool
    http_status: int | None
    proxy_selected: bool = False
    proxy_ok: bool = True
    tls_hostname_ok: bool = True


def earliest_failure(evidence: ProbeEvidence) -> str:
    if evidence.proxy_selected and not evidence.proxy_ok:
        return "proxy"
    if not evidence.dns_ok:
        return "dns"
    if not evidence.tcp_ok:
        return "tcp"
    if not evidence.tls_ok:
        return "tls"
    if not evidence.tls_hostname_ok:
        return "tls-hostname"
    if evidence.http_status is None:
        return "http-no-response"
    if evidence.http_status >= 500:
        return "http-upstream"
    if evidence.http_status >= 400:
        return "http-request"
    return "none"
