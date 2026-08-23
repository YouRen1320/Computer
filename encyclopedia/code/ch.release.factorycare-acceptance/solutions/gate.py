"""Reference solution for the public FactoryCare acceptance exercise."""


def is_releasable(report: dict) -> bool:
    return (
        bool(report.get("http_statuses"))
        and all(code == 200 for code in report["http_statuses"])
        and report.get("cross_tenant_leaks") == 0
        and report.get("ai_core_flow") == "pass"
        and report.get("rollback") == "pass"
        and report.get("restore") == "pass"
    )
