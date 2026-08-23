import pytest

from boundary_audit import ServerDesign, classify_error, run_bounded, validate_server_design


def test_direct_database_and_write_tool_are_rejected() -> None:
    with pytest.raises(AssertionError, match="bypasses"):
        validate_server_design(ServerDesign("postgres_direct", False))
    with pytest.raises(AssertionError, match="read-only"):
        validate_server_design(ServerDesign("java_authoritative_api", True))
    validate_server_design(ServerDesign("java_authoritative_api", False))


def test_protocol_and_execution_errors_remain_distinct() -> None:
    assert classify_error("unknown_method") == "protocol_error"
    assert classify_error("permission_denied") == "tool_execution_error"


def test_budget_and_kill_switch_are_terminal_and_auditable() -> None:
    assert run_bounded(("inspect", "inspect"), 1, True) == ("budget_exhausted", 1)
    assert run_bounded(("inspect", "finish"), 3, False) == ("killed", 0)
    assert run_bounded(("inspect", "finish"), 3, True) == ("completed", 2)
