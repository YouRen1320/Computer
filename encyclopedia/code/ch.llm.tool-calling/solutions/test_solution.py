import json
from datetime import UTC, datetime, timedelta

from solution import Approval, CloseArgs, Principal, Repository, digest_payload, dispatch


def test_solution_approval_and_idempotency_contract() -> None:
    now = datetime(2026, 7, 24, tzinfo=UTC); purpose = "resolve-maintenance-order"
    principal = Principal(5, frozenset({7}), frozenset({7}))
    repo = Repository({7: {"id": 7, "version": 3}})
    raw = {"order_id": 7, "expected_version": 3, "resolution": "Bearing replaced",
           "idempotency_key": "close_7_abc"}
    call = {"call_id": "c1", "name": "close_order", "arguments": json.dumps(raw),
            "approval_id": "a1"}
    args = CloseArgs.model_validate(raw)
    approval = Approval("a1", 5, "close_order", digest_payload(args.model_dump()), 3,
                        purpose, now + timedelta(minutes=5))
    first = dispatch(call, principal=principal, repo=repo, approvals={"a1": approval},
                     now=now, purpose=purpose)
    second = dispatch(call, principal=principal, repo=repo, approvals={"a1": approval},
                      now=now, purpose=purpose)
    assert first["ok"] and second["data"] == first["data"] and repo.close_count == 1


def test_solution_rejects_before_handler() -> None:
    now = datetime(2026, 7, 24, tzinfo=UTC)
    principal = Principal(5, frozenset(), frozenset())
    repo = Repository({7: {"id": 7, "version": 3}})
    assert dispatch({"name": "delete_all", "arguments": "{}"}, principal=principal,
                    repo=repo, approvals={}, now=now, purpose="p")["code"] == "tool_not_allowed"
    assert repo.close_count == 0
