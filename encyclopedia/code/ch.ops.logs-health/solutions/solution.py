"""Reference solution for the local policy exercise."""


def build_layer_records(incoming_id: str) -> list[dict]:
    return [{"service": service, "correlation_id": incoming_id}
            for service in ("nginx", "java-api", "postgresql")]


def probe(process_ok: bool, database_ok: bool) -> dict:
    live = process_ok
    ready = process_ok and database_ok
    return {"liveness_http": 200 if live else 503,
            "readiness_http": 200 if ready else 503}
