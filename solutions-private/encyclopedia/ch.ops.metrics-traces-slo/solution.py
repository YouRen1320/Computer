"""Reference contract for the local exercise."""


def design() -> dict:
    trace_id = "incoming-trace"
    return {"labels": ["service", "route", "status_class"],
            "latency_measure": "threshold-good-event-ratio",
            "alert_signal": "slo-burn-rate",
            "async_trace_id": trace_id, "incoming_trace_id": trace_id}
