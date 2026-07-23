"""Public exercise: this implementation deliberately checks only happy-path HTTP."""


def is_releasable(report: dict) -> bool:
    # Deliberately wrong: 200 responses do not prove isolation, AI fallback or recovery.
    return all(code == 200 for code in report.get("http_statuses", []))
