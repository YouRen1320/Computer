from importlib.metadata import version

import pytest

from workflow import Command, JavaAuthorityFixture, OneShotCrash, build_graph, config, initial_state


def test_approval_and_rejection_paths_terminate_deterministically() -> None:
    approved_authority = JavaAuthorityFixture()
    approved_graph = build_graph(approved_authority)
    approved_config = config("approved-thread")
    paused = approved_graph.invoke(initial_state("run-approved"), approved_config)
    assert "__interrupt__" in paused
    final = approved_graph.invoke(Command(resume="approve"), approved_config)
    assert final["status"] == "completed"
    assert final["receipt_id"].startswith("receipt:WO-42")
    assert approved_authority.committed_writes == 1

    rejected_authority = JavaAuthorityFixture()
    rejected_graph = build_graph(rejected_authority)
    rejected_config = config("rejected-thread")
    rejected_graph.invoke(initial_state("run-rejected"), rejected_config)
    rejected = rejected_graph.invoke(Command(resume="reject"), rejected_config)
    assert rejected["status"] == "rejected"
    assert rejected_authority.committed_writes == 0


def test_crash_after_java_commit_resumes_without_duplicate_write() -> None:
    authority = JavaAuthorityFixture()
    crash = OneShotCrash(enabled=True)
    graph = build_graph(authority, crash)
    thread_config = config("crash-thread")
    graph.invoke(initial_state("run-crash"), thread_config)
    with pytest.raises(RuntimeError, match="injected crash"):
        graph.invoke(Command(resume="approve"), thread_config)
    assert authority.committed_writes == 1
    recovered = graph.invoke(None, thread_config)
    assert recovered["status"] == "completed"
    assert authority.attempts == 2
    assert authority.committed_writes == 1


def test_state_schema_is_checked_before_any_business_step() -> None:
    authority = JavaAuthorityFixture()
    graph = build_graph(authority)
    with pytest.raises(ValueError, match="unsupported workflow state schema"):
        graph.invoke({"schema_version": 0, "run_id": "old", "ticket_id": "WO-42"}, config("old"))
    assert authority.attempts == 0


def test_actual_langgraph_major_surface_is_recorded() -> None:
    assert version("langgraph").startswith("1.")
