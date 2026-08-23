"""Structured-log and health semantics without a logging backend."""
from __future__ import annotations

import json
import re
from typing import Any, Callable


CORRELATION_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]{7,63}$")
BANNED_LOG_KEYS = {"authorization", "token", "password", "secret", "email", "phone", "request_body"}
ALLOWED_LEVELS = {"DEBUG", "INFO", "WARN", "ERROR"}


def correlation_id(incoming: str | None, new_id: Callable[[], str]) -> str:
    if incoming and CORRELATION_PATTERN.fullmatch(incoming):
        return incoming
    generated = new_id()
    if not CORRELATION_PATTERN.fullmatch(generated):
        raise ValueError("generated correlation ID violates the public contract")
    return generated


def structured_log(*, service: str, event: str, level: str,
                   correlation: str, attributes: dict[str, Any]) -> str:
    if level not in ALLOWED_LEVELS:
        raise ValueError("unknown log level")
    forbidden = BANNED_LOG_KEYS & set(attributes)
    if forbidden:
        raise ValueError(f"sensitive log fields rejected: {sorted(forbidden)}")
    record = {"service": service, "event": event, "severity": level,
              "correlation_id": correlation, "attributes": attributes}
    return json.dumps(record, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def health(*, process_ok: bool, startup_complete: bool, postgres_ok: bool,
           optional_provider_ok: bool) -> dict[str, Any]:
    live = process_ok
    ready = process_ok and startup_complete and postgres_ok
    if not process_ok:
        state = "DOWN"
    elif not startup_complete:
        state = "STARTING"
    elif not postgres_ok:
        state = "NOT_READY"
    elif not optional_provider_ok:
        state = "DEGRADED"
    else:
        state = "UP"
    return {"state": state, "live": live, "ready": ready,
            "liveness_http": 200 if live else 503,
            "readiness_http": 200 if ready else 503}


if __name__ == "__main__":
    cid = correlation_id("request-demo-0001", lambda: "request-generated-0001")
    print(structured_log(service="java-api", event="work-order.loaded", level="INFO",
                         correlation=cid, attributes={"route": "/work-orders/{id}", "status": 200}))
    print(json.dumps(health(process_ok=True, startup_complete=True, postgres_ok=True,
                            optional_provider_ok=False), sort_keys=True))
