import hashlib
import json
from dataclasses import dataclass, field
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, ValidationError


class CloseArgs(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    order_id: int = Field(gt=0)
    expected_version: int = Field(gt=0)
    resolution: str = Field(min_length=3)
    idempotency_key: str = Field(pattern=r"^[a-zA-Z0-9_-]{8,64}$")


def digest_payload(value: dict) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


@dataclass(frozen=True)
class Principal:
    user_id: int
    readable: frozenset[int]
    closable: frozenset[int]


@dataclass(frozen=True)
class Approval:
    approval_id: str
    principal_id: int
    tool_name: str
    payload_sha256: str
    resource_version: int
    purpose: str
    expires_at: datetime


@dataclass
class Repository:
    orders: dict[int, dict]
    close_count: int = 0
    receipts: dict[str, tuple[str, dict]] = field(default_factory=dict)

    def get(self, order_id: int) -> dict:
        return dict(self.orders[order_id])

    def close(self, args: CloseArgs) -> dict:
        payload_sha256 = digest_payload(args.model_dump())
        replay = self.receipts.get(args.idempotency_key)
        if replay:
            previous_sha256, receipt = replay
            if previous_sha256 != payload_sha256:
                raise ValueError("idempotency_conflict")
            return dict(receipt)
        if self.orders[args.order_id]["version"] != args.expected_version:
            raise RuntimeError("stale_resource")
        self.close_count += 1
        receipt = {"order_id": args.order_id, "status": "CLOSED",
                   "resolution": args.resolution}
        self.receipts[args.idempotency_key] = (payload_sha256, dict(receipt))
        return receipt


def dispatch(call: dict, *, principal: Principal, repo: Repository,
             approvals: dict[str, Approval], now: datetime, purpose: str) -> dict:
    name = call.get("name")
    if name not in {"get_order", "close_order"}:
        return {"ok": False, "code": "tool_not_allowed"}
    try:
        raw = json.loads(call.get("arguments", ""))
        if name == "get_order":
            if set(raw) != {"order_id"} or not isinstance(raw["order_id"], int):
                return {"ok": False, "code": "invalid_arguments"}
            if raw["order_id"] not in principal.readable:
                return {"ok": False, "code": "forbidden"}
            return {"ok": True, "code": "ok", "data": repo.get(raw["order_id"])}
        args = CloseArgs.model_validate(raw)
    except (ValueError, TypeError, KeyError, ValidationError):
        return {"ok": False, "code": "invalid_arguments"}
    if args.order_id not in principal.closable:
        return {"ok": False, "code": "forbidden"}
    approval = approvals.get(call.get("approval_id"))
    if approval is None:
        return {"ok": False, "code": "confirmation_required"}
    if approval.expires_at <= now:
        return {"ok": False, "code": "approval_expired"}
    expected = (principal.user_id, name, digest_payload(args.model_dump()),
                args.expected_version, purpose)
    actual = (approval.principal_id, approval.tool_name, approval.payload_sha256,
              approval.resource_version, approval.purpose)
    if actual != expected:
        return {"ok": False, "code": "approval_mismatch"}
    try:
        receipt = repo.close(args)
    except ValueError as error:
        if str(error) == "idempotency_conflict":
            return {"ok": False, "code": "idempotency_conflict"}
        raise
    except RuntimeError:
        return {"ok": False, "code": "stale_resource"}
    return {"ok": True, "code": "ok", "data": receipt}
