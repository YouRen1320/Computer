from dataclasses import dataclass


@dataclass(frozen=True)
class ServerDesign:
    backend: str
    has_write_tool: bool


def validate_server_design(design: ServerDesign) -> None:
    if design.backend != "java_authoritative_api":
        raise AssertionError("MCP server bypasses authoritative Java API")
    if design.has_write_tool:
        raise AssertionError("teaching MCP boundary must remain read-only")


def classify_error(kind: str) -> str:
    if kind in {"unknown_method", "malformed_request", "invalid_jsonrpc"}:
        return "protocol_error"
    if kind in {"permission_denied", "not_found", "business_validation"}:
        return "tool_execution_error"
    raise ValueError("unknown error kind")


def run_bounded(plan: tuple[str, ...], budget: int, enabled: bool) -> tuple[str, int]:
    steps = 0
    for action in plan:
        if not enabled:
            return "killed", steps
        if steps >= budget:
            return "budget_exhausted", steps
        steps += 1
        if action == "finish":
            return "completed", steps
    return "plan_exhausted", steps
