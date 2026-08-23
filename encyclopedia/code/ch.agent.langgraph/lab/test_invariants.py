import pytest

from invariants import IdempotentAuthority, approval_route, bounded_retry, require_state_version


def test_unversioned_or_old_state_is_rejected() -> None:
    with pytest.raises(ValueError, match="state version"):
        require_state_version({"ticket_id": "WO-1"})
    with pytest.raises(ValueError, match="state version"):
        require_state_version({"schema_version": 0})
    require_state_version({"schema_version": 1})


def test_replayed_side_effect_uses_same_idempotency_key() -> None:
    authority = IdempotentAuthority()
    first = authority.write("run-1:execute")
    second = authority.write("run-1:execute")
    assert first == second
    assert authority.writes == 1


def test_rejection_timeout_and_cancel_never_follow_success_edge() -> None:
    assert approval_route("approve") == "execute"
    for decision in ("reject", "timeout", "cancel"):
        assert approval_route(decision) == "terminate"


def test_loop_has_observable_budget_exhaustion() -> None:
    assert bounded_retry(success_on=2, budget=3) == ("succeeded", 2)
    assert bounded_retry(success_on=None, budget=3) == ("budget_exhausted", 3)
