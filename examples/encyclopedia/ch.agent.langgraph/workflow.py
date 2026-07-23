from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal, TypedDict

from langgraph.checkpoint.memory import InMemorySaver
from langgraph.graph import END, START, StateGraph
from langgraph.types import Command, interrupt


class WorkflowState(TypedDict, total=False):
    schema_version: int
    run_id: str
    ticket_id: str
    evidence: tuple[str, ...]
    diagnosis: str
    proposed_action: str
    approval: Literal["approve", "reject"]
    receipt_id: str
    status: str


@dataclass
class JavaAuthorityFixture:
    """A local substitute for the authoritative Java API, not a database."""

    receipts_by_key: dict[str, str] = field(default_factory=dict)
    attempts: int = 0
    committed_writes: int = 0

    def apply_proposal(self, ticket_id: str, action: str, idempotency_key: str) -> str:
        self.attempts += 1
        existing = self.receipts_by_key.get(idempotency_key)
        if existing is not None:
            return existing
        receipt = f"receipt:{ticket_id}:{action}"
        self.receipts_by_key[idempotency_key] = receipt
        self.committed_writes += 1
        return receipt


@dataclass
class OneShotCrash:
    enabled: bool = False
    fired: bool = False

    def after_commit(self) -> None:
        if self.enabled and not self.fired:
            self.fired = True
            raise RuntimeError("injected crash after authoritative commit")


def build_graph(
    authority: JavaAuthorityFixture,
    crash: OneShotCrash | None = None,
):
    crash = crash or OneShotCrash()

    def validate(state: WorkflowState) -> dict[str, object]:
        if state.get("schema_version") != 1:
            raise ValueError("unsupported workflow state schema")
        if not state.get("run_id") or not state.get("ticket_id"):
            raise ValueError("run_id and ticket_id are required")
        return {"status": "validated"}

    def retrieve(state: WorkflowState) -> dict[str, object]:
        return {"evidence": (f"manual evidence for {state['ticket_id']}",), "status": "retrieved"}

    def analyze(state: WorkflowState) -> dict[str, object]:
        if not state.get("evidence"):
            raise ValueError("analysis requires evidence")
        return {"diagnosis": "cooling-loop-check", "status": "analyzed"}

    def propose(state: WorkflowState) -> dict[str, object]:
        if state.get("diagnosis") != "cooling-loop-check":
            raise ValueError("unsupported diagnosis")
        return {"proposed_action": "REQUEST_INSPECTION", "status": "awaiting_approval"}

    def approval(state: WorkflowState) -> dict[str, object]:
        decision = interrupt(
            {
                "schema_version": 1,
                "run_id": state["run_id"],
                "ticket_id": state["ticket_id"],
                "proposed_action": state["proposed_action"],
            }
        )
        if decision not in {"approve", "reject"}:
            raise ValueError("approval must be approve or reject")
        return {"approval": decision}

    def approval_route(state: WorkflowState) -> str:
        return "execute" if state.get("approval") == "approve" else "reject"

    def execute(state: WorkflowState) -> dict[str, object]:
        key = f"{state['run_id']}:execute:{state['proposed_action']}"
        receipt = authority.apply_proposal(
            state["ticket_id"], state["proposed_action"], idempotency_key=key
        )
        crash.after_commit()
        return {"receipt_id": receipt, "status": "executed"}

    def reject(state: WorkflowState) -> dict[str, object]:
        del state
        return {"status": "rejected"}

    def summarize(state: WorkflowState) -> dict[str, object]:
        if state.get("status") == "executed" and not state.get("receipt_id"):
            raise ValueError("executed workflow requires authoritative receipt")
        return {"status": "completed"}

    builder = StateGraph(WorkflowState)
    builder.add_node("validate", validate)
    builder.add_node("retrieve", retrieve)
    builder.add_node("analyze", analyze)
    builder.add_node("propose", propose)
    builder.add_node("approval", approval)
    builder.add_node("execute", execute)
    builder.add_node("reject", reject)
    builder.add_node("summarize", summarize)
    builder.add_edge(START, "validate")
    builder.add_edge("validate", "retrieve")
    builder.add_edge("retrieve", "analyze")
    builder.add_edge("analyze", "propose")
    builder.add_edge("propose", "approval")
    builder.add_conditional_edges("approval", approval_route, {"execute": "execute", "reject": "reject"})
    builder.add_edge("execute", "summarize")
    builder.add_edge("summarize", END)
    builder.add_edge("reject", END)
    return builder.compile(checkpointer=InMemorySaver())


def initial_state(run_id: str) -> WorkflowState:
    return {"schema_version": 1, "run_id": run_id, "ticket_id": "WO-42"}


def config(thread_id: str) -> dict[str, dict[str, str]]:
    return {"configurable": {"thread_id": thread_id}}


__all__ = [
    "Command",
    "JavaAuthorityFixture",
    "OneShotCrash",
    "build_graph",
    "config",
    "initial_state",
]
