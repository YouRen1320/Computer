"""Intentionally broken correlation and health policy."""


def build_layer_records(incoming_id: str) -> list[dict]:
    return [
        {"service": "nginx", "correlation_id": incoming_id},
        {"service": "java-api", "correlation_id": "rebuilt-at-api",
         "sensitive_fields_logged": ["authorization"]},
        {"service": "postgresql", "correlation_id": "rebuilt-at-database"},
    ]


def probe(process_ok: bool, database_ok: bool) -> dict:
    return {"liveness_http": 200, "readiness_http": 200}
