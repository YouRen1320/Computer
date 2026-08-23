"""Editable tool-dispatch starter with an intentionally unsafe dispatcher."""

import hashlib
import json
from dataclasses import dataclass, field
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


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
    receipts: dict[str, dict] = field(default_factory=dict)

    def get(self, order_id: int) -> dict:
        return dict(self.orders[order_id])

    def close(self, args: dict) -> dict:
        if args["idempotency_key"] in self.receipts:
            return self.receipts[args["idempotency_key"]]
        self.close_count += 1
        receipt = {"order_id": args["order_id"], "status": "CLOSED",
                   "resolution": args["resolution"]}
        self.receipts[args["idempotency_key"]] = receipt
        return receipt


def dispatch(call: dict, *, principal: Principal, repo: Repository,
             approvals: dict[str, Approval], now: datetime, purpose: str) -> dict:
    del principal, approvals, now, purpose
    args = json.loads(call["arguments"])
    if call["name"] == "get_order":
        return {"ok": True, "code": "ok", "data": repo.get(args["order_id"])}
    return {"ok": True, "code": "ok", "data": repo.close(args)}
