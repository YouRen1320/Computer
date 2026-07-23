"""Intentionally broken metric, trace and alert design."""


def design() -> dict:
    return {
        "labels": ["route", "user_id"],
        "latency_measure": "average",
        "alert_signal": "cpu_percent",
        "async_trace_id": "new-trace-at-worker",
        "incoming_trace_id": "incoming-trace",
    }
