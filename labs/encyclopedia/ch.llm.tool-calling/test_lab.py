import json
from dataclasses import dataclass, field

from pydantic import BaseModel, ConfigDict, Field, ValidationError


class GetOrderArgs(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    order_id: int = Field(gt=0)


class CloseOrderArgs(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    order_id: int = Field(gt=0)
    resolution: str = Field(min_length=3, max_length=120)
    idempotency_key: str = Field(pattern=r"^[a-zA-Z0-9_-]{8,64}$")


@dataclass
class JavaRepositoryBoundary:
    """Fixture stands in for the authoritative Java service, not a Python-owned database."""
    orders: dict[int, dict]
    close_count: int = 0
    receipts: dict[str, dict] = field(default_factory=dict)

    def get(self, order_id: int) -> dict | None:
        value = self.orders.get(order_id)
        return dict(value) if value else None

    def close(self, order_id: int, resolution: str, key: str) -> dict:
        if key in self.receipts:
            return self.receipts[key]
        self.close_count += 1
        self.orders[order_id]["status"] = "CLOSED"
        receipt = {"order_id": order_id, "status": "CLOSED", "resolution": resolution}
        self.receipts[key] = receipt
        return receipt


@dataclass(frozen=True)
class Principal:
    user_id: int
    readable_order_ids: frozenset[int]
    closable_order_ids: frozenset[int]


def envelope(call_id: str, ok: bool, code: str, data=None) -> dict:
    return {"call_id": call_id, "ok": ok, "code": code, "data": data}


def dispatch(call: dict, *, principal: Principal, repo: JavaRepositoryBoundary,
             approved_call_ids: frozenset[str], audit: list[dict]) -> dict:
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
    if args.order_id not in principal.closable_order_ids:
        return envelope(call_id, False, "forbidden")
    if call_id not in approved_call_ids:
        audit.append({"call_id": call_id, "decision": "awaiting_approval", "order_id": args.order_id})
        return envelope(call_id, False, "confirmation_required")
    result = repo.close(args.order_id, args.resolution, args.idempotency_key)
    audit.append({"call_id": call_id, "decision": "executed", "order_id": args.order_id,
                  "idempotency_key": args.idempotency_key})
    return envelope(call_id, True, "ok", result)


def fixture():
    return JavaRepositoryBoundary({7: {"id": 7, "status": "CREATED"}, 9: {"id": 9, "status": "CREATED"}}), Principal(3, frozenset({7}), frozenset({7})), []


def test_unknown_and_invalid_never_execute() -> None:
    repo, user, audit = fixture()
    assert dispatch({"call_id": "c1", "name": "os_system", "arguments": "{}"}, principal=user, repo=repo, approved_call_ids=frozenset(), audit=audit)["code"] == "tool_not_allowed"
    assert dispatch({"call_id": "c2", "name": "close_order", "arguments": '{"order_id":7,"resolution":"ok","idempotency_key":"12345678","extra":1}'}, principal=user, repo=repo, approved_call_ids=frozenset({"c2"}), audit=audit)["code"] == "invalid_arguments"
    assert repo.close_count == 0


def test_resource_authorization_is_rechecked() -> None:
    repo, user, audit = fixture()
    call = {"call_id": "c3", "name": "get_order", "arguments": '{"order_id":9}'}
    assert dispatch(call, principal=user, repo=repo, approved_call_ids=frozenset(), audit=audit)["code"] == "forbidden"


def test_close_requires_confirmation_and_is_idempotent() -> None:
    repo, user, audit = fixture()
    call = {"call_id": "c4", "name": "close_order", "arguments": json.dumps({
        "order_id": 7, "resolution": "Bearing replaced", "idempotency_key": "close_7_abc"})}
    assert dispatch(call, principal=user, repo=repo, approved_call_ids=frozenset(), audit=audit)["code"] == "confirmation_required"
    first = dispatch(call, principal=user, repo=repo, approved_call_ids=frozenset({"c4"}), audit=audit)
    second = dispatch({**call, "call_id": "c5"}, principal=user, repo=repo, approved_call_ids=frozenset({"c5"}), audit=audit)
    assert first["ok"] and second["ok"] and repo.close_count == 1
    assert [row["decision"] for row in audit] == ["awaiting_approval", "executed", "executed"]
