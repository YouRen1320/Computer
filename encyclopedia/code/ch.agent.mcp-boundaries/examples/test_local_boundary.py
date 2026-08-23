import asyncio
from importlib.metadata import version

import mcp.types as mcp_types
import pytest
from mcp.shared.memory import create_connected_server_and_client_session

from local_boundary import (
    BudgetExhausted,
    JavaAuthorityFixture,
    KillSwitch,
    KillSwitchOpen,
    Principal,
    ToolExecutionFailure,
    build_server,
    run_read_workflow,
)


def authority() -> JavaAuthorityFixture:
    return JavaAuthorityFixture(
        {
            "WO-A": {"tenant_id": "tenant-A", "status": "ASSIGNED", "version": 7},
            "WO-B": {"tenant_id": "tenant-B", "status": "CLOSED", "version": 2},
        }
    )


async def successful_scenario() -> None:
    java = authority()
    server = build_server(Principal("u-1", "tenant-A"), java)
    async with create_connected_server_and_client_session(server) as session:
        tools = await session.list_tools()
        assert [tool.name for tool in tools.tools] == ["get_work_order"]
        tool = tools.tools[0]
        assert tool.inputSchema["required"] == ["ticket_id"]
        assert tool.annotations is not None and tool.annotations.readOnlyHint is True
        templates = await session.list_resource_templates()
        assert len(templates.resourceTemplates) == 1
        result = await run_read_workflow(
            session,
            "WO-A",
            budget=1,
            kill_switch=KillSwitch(),
        )
        assert result["work_order"] == {"ticket_id": "WO-A", "status": "ASSIGNED", "version": 7}
        assert result["recommendation"] == "suggest-review:ASSIGNED"
        assert java.reads == 1


async def denied_and_budget_scenario() -> None:
    java = authority()
    server = build_server(Principal("u-1", "tenant-A"), java)
    async with create_connected_server_and_client_session(server) as session:
        with pytest.raises(ToolExecutionFailure, match="execution error"):
            await run_read_workflow(session, "WO-B", budget=1, kill_switch=KillSwitch())
        reads_after_denied = java.reads
        with pytest.raises(BudgetExhausted, match="budget exhausted"):
            await run_read_workflow(session, "WO-A", budget=0, kill_switch=KillSwitch())
        assert java.reads == reads_after_denied
        disabled = KillSwitch(enabled=False)
        with pytest.raises(KillSwitchOpen, match="disabled"):
            await run_read_workflow(session, "WO-A", budget=1, kill_switch=disabled)
        assert disabled.audit == ["killed:tool-call"]
        assert java.reads == reads_after_denied


def test_real_local_mcp_server_client_and_langgraph_boundary() -> None:
    asyncio.run(successful_scenario())


def test_permission_error_budget_and_kill_switch_terminate() -> None:
    asyncio.run(denied_and_budget_scenario())


def test_actual_sdk_and_protocol_surface_are_recorded() -> None:
    assert version("mcp") == "1.28.1"
    assert mcp_types.LATEST_PROTOCOL_VERSION == "2025-11-25"
