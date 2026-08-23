import json
from dataclasses import replace
from datetime import UTC, datetime, timedelta

from exercise import Approval, CloseArgs, Principal, Repository, digest_payload, dispatch


NOW = datetime(2026, 7, 24, tzinfo=UTC)
PURPOSE = "resolve-maintenance-order"


def fixture():
    return (Repository({7: {"id": 7, "version": 3}, 9: {"id": 9, "version": 1}}),
            Principal(5, frozenset({7}), frozenset({7})))


def close_call(**changes) -> dict:
    args = {"order_id": 7, "expected_version": 3, "resolution": "Bearing replaced",
            "idempotency_key": "close_7_abc"}
    args.update(changes)
    return {"call_id": "call-1", "name": "close_order",
            "arguments": json.dumps(args), "approval_id": "approval-1"}


def approval_for(call: dict, principal: Principal, **changes) -> Approval:
    args = CloseArgs.model_validate_json(call["arguments"])
    values = {
        "approval_id": call["approval_id"], "principal_id": principal.user_id,
        "tool_name": call["name"], "payload_sha256": digest_payload(args.model_dump()),
        "resource_version": args.expected_version, "purpose": PURPOSE,
        "expires_at": NOW + timedelta(minutes=5),
    }
    values.update(changes)
    return Approval(**values)


def run(call, repo, principal, approvals):
    return dispatch(call, principal=principal, repo=repo, approvals=approvals,
                    now=NOW, purpose=PURPOSE)


def test_allowlist_schema_and_resource_authorization_run_before_handler() -> None:
    repo, principal = fixture()
    assert run({"call_id": "x", "name": "delete_all", "arguments": "{}"},
               repo, principal, {})["code"] == "tool_not_allowed"
    invalid = close_call(extra=True)
    assert run(invalid, repo, principal, {})["code"] == "invalid_arguments"
    read_other = {"call_id": "r", "name": "get_order", "arguments": '{"order_id":9}'}
    assert run(read_other, repo, principal, {})["code"] == "forbidden"
    assert repo.close_count == 0


def test_close_requires_exact_unexpired_payload_bound_approval() -> None:
    repo, principal = fixture(); call = close_call()
    assert run(call, repo, principal, {})["code"] == "confirmation_required"
    base = approval_for(call, principal)
    variants = (
        replace(base, principal_id=99), replace(base, tool_name="get_order"),
        replace(base, payload_sha256="0" * 64), replace(base, resource_version=2),
        replace(base, purpose="other"), replace(base, expires_at=NOW),
    )
    for approval in variants:
        assert not run(call, repo, principal, {approval.approval_id: approval})["ok"]
    assert repo.close_count == 0


def test_idempotent_replay_and_payload_conflict_call_handler_once() -> None:
    repo, principal = fixture(); call = close_call(); approval = approval_for(call, principal)
    first = run(call, repo, principal, {approval.approval_id: approval})
    second = run({**call, "call_id": "call-2"}, repo, principal,
                 {approval.approval_id: approval})
    assert first["ok"] and second["data"] == first["data"] and repo.close_count == 1
    changed = close_call(resolution="Different resolution")
    changed["approval_id"] = "approval-2"
    changed_approval = approval_for(changed, principal)
    conflict = run(changed, repo, principal,
                   {changed_approval.approval_id: changed_approval})
    assert conflict["code"] == "idempotency_conflict"
    assert repo.close_count == 1
