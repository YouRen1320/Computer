import hashlib
import json
from dataclasses import dataclass, field, replace
from datetime import UTC, datetime, timedelta

from pydantic import BaseModel, ConfigDict, Field, ValidationError


class GetOrderArgs(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    order_id: int = Field(gt=0)


class CloseOrderArgs(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    order_id: int = Field(gt=0)
    expected_version: int = Field(gt=0)
    resolution: str = Field(min_length=3, max_length=120)
    idempotency_key: str = Field(pattern=r"^[a-zA-Z0-9_-]{8,64}$")


class IdempotencyConflict(RuntimeError):
    pass


class StaleResource(RuntimeError):
    pass


def digest_payload(value: dict) -> str:
    canonical = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode()).hexdigest()


@dataclass
class JavaRepositoryBoundary:
    """Fixture stands in for the authoritative Java service, not a Python-owned database."""

    orders: dict[int, dict]
    close_count: int = 0
    receipts: dict[str, tuple[str, dict]] = field(default_factory=dict)

    def get(self, order_id: int) -> dict | None:
        value = self.orders.get(order_id)
        return dict(value) if value else None

    def close(self, args: CloseOrderArgs) -> dict:
        payload_digest = digest_payload(args.model_dump(mode="json"))
        replay = self.receipts.get(args.idempotency_key)
        if replay is not None:
            previous_digest, receipt = replay
            if previous_digest != payload_digest:
                raise IdempotencyConflict("same idempotency key was reused for different payload")
            return dict(receipt)

        order = self.orders[args.order_id]
        if order["version"] != args.expected_version:
            raise StaleResource("order version changed before execution")
        self.close_count += 1
        order.update(status="CLOSED", version=order["version"] + 1)
        receipt = {
            "order_id": args.order_id,
            "status": "CLOSED",
            "resolution": args.resolution,
            "version": order["version"],
        }
        self.receipts[args.idempotency_key] = (payload_digest, dict(receipt))
        return receipt


@dataclass(frozen=True)
class Principal:
    user_id: int
    readable_order_ids: frozenset[int]
    closable_order_ids: frozenset[int]


@dataclass(frozen=True)
class Approval:
    approval_id: str
    principal_id: int
    tool_name: str
    arguments_sha256: str
    resource_version: int
    purpose: str
    expires_at: datetime


def approval_for(call: dict, *, principal: Principal, purpose: str,
                 expires_at: datetime, approval_id: str = "approval-1") -> Approval:
    args = CloseOrderArgs.model_validate_json(call["arguments"])
    return Approval(
        approval_id=approval_id,
        principal_id=principal.user_id,
        tool_name=call["name"],
        arguments_sha256=digest_payload(args.model_dump(mode="json")),
        resource_version=args.expected_version,
        purpose=purpose,
        expires_at=expires_at,
    )


def envelope(call_id: str, ok: bool, code: str, data=None) -> dict:
    return {"call_id": call_id, "ok": ok, "code": code, "data": data}


def dispatch(call: dict, *, principal: Principal, repo: JavaRepositoryBoundary,
             approvals: dict[str, Approval], purpose: str, now: datetime,
             audit: list[dict]) -> dict:
    call_id, name = call.get("call_id", "missing"), call.get("name")
    schemas = {"get_order": GetOrderArgs, "close_order": CloseOrderArgs}
    if name not in schemas:
        audit.append({"call_id": call_id, "decision": "deny", "reason": "tool_not_allowed"})
        return envelope(call_id, False, "tool_not_allowed")
    try:
        args = schemas[name].model_validate_json(call.get("arguments", ""))
    except (ValidationError, ValueError):
        audit.append({"call_id": call_id, "decision": "deny", "reason": "invalid_arguments"})
        return envelope(call_id, False, "invalid_arguments")
    if name == "get_order":
        if args.order_id not in principal.readable_order_ids:
            return envelope(call_id, False, "forbidden")
        return envelope(call_id, True, "ok", repo.get(args.order_id))
    assert isinstance(args, CloseOrderArgs)
    if args.order_id not in principal.closable_order_ids:
        return envelope(call_id, False, "forbidden")

    approval = approvals.get(call.get("approval_id"))
    if approval is None:
        audit.append({"call_id": call_id, "decision": "awaiting_approval",
                      "order_id": args.order_id})
        return envelope(call_id, False, "confirmation_required")
    if approval.expires_at <= now:
        return envelope(call_id, False, "approval_expired")
    expected_binding = (
        principal.user_id,
        name,
        digest_payload(args.model_dump(mode="json")),
        args.expected_version,
        purpose,
    )
    actual_binding = (
        approval.principal_id,
        approval.tool_name,
        approval.arguments_sha256,
        approval.resource_version,
        approval.purpose,
    )
    if actual_binding != expected_binding:
        return envelope(call_id, False, "approval_mismatch")
    try:
        result = repo.close(args)
    except IdempotencyConflict:
        return envelope(call_id, False, "idempotency_conflict")
    except StaleResource:
        return envelope(call_id, False, "stale_resource")
    audit.append({
        "call_id": call_id,
        "decision": "executed",
        "order_id": args.order_id,
        "approval_id": approval.approval_id,
        "payload_sha256": approval.arguments_sha256,
        "idempotency_key": args.idempotency_key,
    })
    return envelope(call_id, True, "ok", result)


NOW = datetime(2026, 7, 24, tzinfo=UTC)
PURPOSE = "resolve-authorized-maintenance-order"


def fixture():
    orders = {
        7: {"id": 7, "status": "IN_PROGRESS", "version": 3},
        9: {"id": 9, "status": "IN_PROGRESS", "version": 5},
    }
    principal = Principal(3, frozenset({7}), frozenset({7}))
    return JavaRepositoryBoundary(orders), principal, []


def close_call(**changes: object) -> dict:
    arguments = {
        "order_id": 7,
        "expected_version": 3,
        "resolution": "Bearing replaced",
        "idempotency_key": "close_7_abc",
    }
    arguments.update(changes)
    return {"call_id": "c4", "name": "close_order",
            "arguments": json.dumps(arguments), "approval_id": "approval-1"}


def run(call: dict, *, repo: JavaRepositoryBoundary, principal: Principal,
        approvals: dict[str, Approval], audit: list[dict], purpose: str = PURPOSE,
        now: datetime = NOW) -> dict:
    return dispatch(call, principal=principal, repo=repo, approvals=approvals,
                    purpose=purpose, now=now, audit=audit)


def test_unknown_and_invalid_never_execute() -> None:
    repo, user, audit = fixture()
    unknown = {"call_id": "c1", "name": "os_system", "arguments": "{}"}
    assert run(unknown, repo=repo, principal=user, approvals={}, audit=audit)["code"] == "tool_not_allowed"
    invalid = {"call_id": "c2", "name": "close_order",
               "arguments": '{"order_id":7,"expected_version":3,"resolution":"ok","idempotency_key":"12345678","extra":1}'}
    assert run(invalid, repo=repo, principal=user, approvals={}, audit=audit)["code"] == "invalid_arguments"
    assert repo.close_count == 0


def test_resource_authorization_is_rechecked() -> None:
    repo, user, audit = fixture()
    call = {"call_id": "c3", "name": "get_order", "arguments": '{"order_id":9}'}
    assert run(call, repo=repo, principal=user, approvals={}, audit=audit)["code"] == "forbidden"


def test_exact_approval_executes_and_exact_idempotent_replay_runs_handler_once() -> None:
    repo, user, audit = fixture()
    call = close_call()
    assert run(call, repo=repo, principal=user, approvals={}, audit=audit)["code"] == "confirmation_required"
    approval = approval_for(call, principal=user, purpose=PURPOSE,
                            expires_at=NOW + timedelta(minutes=5))
    first = run(call, repo=repo, principal=user, approvals={approval.approval_id: approval}, audit=audit)
    second = run({**call, "call_id": "c5"}, repo=repo, principal=user,
                 approvals={approval.approval_id: approval}, audit=audit)
    assert first["ok"] and second["ok"] and first["data"] == second["data"]
    assert repo.close_count == 1


def test_approval_is_bound_to_every_security_dimension() -> None:
    _, user, _ = fixture()
    call = close_call()
    base = approval_for(call, principal=user, purpose=PURPOSE,
                        expires_at=NOW + timedelta(minutes=5))
    variants = (
        replace(base, principal_id=999),
        replace(base, tool_name="different_tool"),
        replace(base, arguments_sha256="0" * 64),
        replace(base, resource_version=2),
        replace(base, purpose="different-purpose"),
    )
    for approval in variants:
        repo, principal, audit = fixture()
        result = run(call, repo=repo, principal=principal,
                     approvals={approval.approval_id: approval}, audit=audit)
        assert result["code"] == "approval_mismatch"
        assert repo.close_count == 0

    repo, principal, audit = fixture()
    expired = replace(base, expires_at=NOW)
    assert run(call, repo=repo, principal=principal,
               approvals={expired.approval_id: expired}, audit=audit)["code"] == "approval_expired"
    assert repo.close_count == 0


def test_same_idempotency_key_with_different_payload_is_a_stable_conflict() -> None:
    repo, user, audit = fixture()
    first_call = close_call()
    first_approval = approval_for(first_call, principal=user, purpose=PURPOSE,
                                  expires_at=NOW + timedelta(minutes=5), approval_id="approval-1")
    assert run(first_call, repo=repo, principal=user,
               approvals={first_approval.approval_id: first_approval}, audit=audit)["ok"]

    changed_call = close_call(resolution="Different resolution")
    changed_call["approval_id"] = "approval-2"
    changed_approval = approval_for(changed_call, principal=user, purpose=PURPOSE,
                                    expires_at=NOW + timedelta(minutes=5), approval_id="approval-2")
    conflict = run(changed_call, repo=repo, principal=user,
                   approvals={changed_approval.approval_id: changed_approval}, audit=audit)
    assert conflict["code"] == "idempotency_conflict"
    assert repo.close_count == 1
