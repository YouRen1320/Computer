from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import TypedDict

from langgraph.graph import END, START, StateGraph
from mcp import ClientSession
from mcp.server.fastmcp import FastMCP
from mcp.types import ToolAnnotations


class BudgetExhausted(RuntimeError):
    pass


class KillSwitchOpen(RuntimeError):
    pass


class ToolExecutionFailure(RuntimeError):
    pass


@dataclass(frozen=True)
class Principal:
    subject_id: str
    tenant_id: str


@dataclass
class JavaAuthorityFixture:
    """In-memory substitute for Java's authorized read API; never a direct DB handle."""

    records: dict[str, dict[str, object]]
    reads: int = 0

    def get_work_order(self, principal: Principal, ticket_id: str) -> dict[str, object]:
        self.reads += 1
        record = self.records.get(ticket_id)
        if record is None:
            raise LookupError("work order not found")
        if record["tenant_id"] != principal.tenant_id:
            raise PermissionError("Java authority denied cross-tenant read")
        return {
            "ticket_id": ticket_id,
            "status": record["status"],
            "version": record["version"],
        }


@dataclass
class KillSwitch:
    enabled: bool = True
    audit: list[str] = field(default_factory=list)

    def require_enabled(self, phase: str) -> None:
        if not self.enabled:
            self.audit.append(f"killed:{phase}")
            raise KillSwitchOpen(f"agent disabled before {phase}")


def build_server(principal: Principal, java_api: JavaAuthorityFixture) -> FastMCP:
    server = FastMCP(
        "factorycare-readonly-fixture",
        instructions="Read-only work-order context. Java remains authoritative.",
    )

    @server.tool(
        name="get_work_order",
        title="Get authorized work order",
        description="Read one work order through the authoritative Java API fixture.",
        annotations=ToolAnnotations(
            readOnlyHint=True,
            destructiveHint=False,
            idempotentHint=True,
            openWorldHint=False,
        ),
        structured_output=True,
    )
    def get_work_order(ticket_id: str) -> dict[str, object]:
        return java_api.get_work_order(principal, ticket_id)

    @server.resource(
        "factorycare://work-orders/{ticket_id}",
        name="work_order_resource",
        description="Authorized read-only projection from the Java API fixture.",
        mime_type="application/json",
    )
    def work_order_resource(ticket_id: str) -> str:
        return json.dumps(java_api.get_work_order(principal, ticket_id), ensure_ascii=False)

    return server


class ReadState(TypedDict, total=False):
    ticket_id: str
    steps_remaining: int
    work_order: dict[str, object]
    recommendation: str


async def run_read_workflow(
    session: ClientSession,
    ticket_id: str,
    *,
    budget: int,
    kill_switch: KillSwitch,
) -> ReadState:
    """A bounded deterministic LangGraph client; it never performs a business write."""

    async def read_node(state: ReadState) -> dict[str, object]:
        kill_switch.require_enabled("tool-call")
        remaining = state["steps_remaining"]
        if remaining <= 0:
            raise BudgetExhausted("agent step budget exhausted")
        result = await session.call_tool("get_work_order", {"ticket_id": state["ticket_id"]})
        if result.isError:
            # Preserve the tool error as control flow; do not turn it into model context.
            raise ToolExecutionFailure("MCP tool reported an execution error")
        if result.structuredContent is None:
            raise ToolExecutionFailure("MCP tool omitted structuredContent")
        kill_switch.require_enabled("post-tool")
        return {
            "steps_remaining": remaining - 1,
            "work_order": dict(result.structuredContent),
        }

    def propose_node(state: ReadState) -> dict[str, object]:
        kill_switch.require_enabled("proposal")
        status = state["work_order"]["status"]
        return {"recommendation": f"suggest-review:{status}"}

    builder = StateGraph(ReadState)
    builder.add_node("read", read_node)
    builder.add_node("propose", propose_node)
    builder.add_edge(START, "read")
    builder.add_edge("read", "propose")
    builder.add_edge("propose", END)
    graph = builder.compile()
    return await graph.ainvoke({"ticket_id": ticket_id, "steps_remaining": budget})
