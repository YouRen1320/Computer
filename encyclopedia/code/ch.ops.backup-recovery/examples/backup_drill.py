"""Deterministic restore-drill model for FactoryCare.

This module deliberately uses a TEST-ONLY authenticated envelope.  It proves
control flow, tamper detection, target isolation and domain invariants; it is
not a substitute for PostgreSQL encryption, pg_verifybackup or a real restore.
"""

from __future__ import annotations

import hashlib
import hmac
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


KNOWN_STATUSES = {
    "CREATED",
    "TRIAGED",
    "ASSIGNED",
    "ACCEPTED",
    "IN_PROGRESS",
    "PENDING_PARTS",
    "PENDING_APPROVAL",
    "RESOLVED",
    "VERIFIED",
    "CLOSED",
    "REOPENED",
    "CANCELLED",
}
LEGAL_TRANSITIONS = {
    ("CREATED", "TRIAGED"),
    ("CREATED", "CANCELLED"),
    ("TRIAGED", "ASSIGNED"),
    ("TRIAGED", "CANCELLED"),
    ("ASSIGNED", "ACCEPTED"),
    ("ACCEPTED", "IN_PROGRESS"),
    ("IN_PROGRESS", "PENDING_PARTS"),
    ("PENDING_PARTS", "IN_PROGRESS"),
    ("IN_PROGRESS", "PENDING_APPROVAL"),
    ("PENDING_APPROVAL", "IN_PROGRESS"),
    ("IN_PROGRESS", "RESOLVED"),
    ("RESOLVED", "VERIFIED"),
    ("RESOLVED", "IN_PROGRESS"),
    ("VERIFIED", "CLOSED"),
    ("CLOSED", "REOPENED"),
    ("REOPENED", "IN_PROGRESS"),
}


@dataclass(frozen=True)
class BackupEnvelope:
    backup_id: str
    cutoff: datetime
    key_id: str
    backup_location: str
    key_location: str
    nonce: bytes
    ciphertext: bytes
    authentication_tag: bytes
    plaintext_sha256: str
    ciphertext_sha256: str


@dataclass
class RestoreTarget:
    name: str
    environment: str
    empty: bool = True


@dataclass(frozen=True)
class DrillResult:
    rpo_seconds: float
    rto_seconds: float
    row_counts: dict[str, int]
    snapshot_sha256: str


def _canonical_bytes(snapshot: dict[str, Any]) -> bytes:
    return json.dumps(snapshot, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _xor(payload: bytes, key: bytes, nonce: bytes) -> bytes:
    """A deterministic teaching transform, explicitly not production crypto."""
    stream = hashlib.sha256(key + nonce).digest()
    return bytes(value ^ stream[index % len(stream)] for index, value in enumerate(payload))


def create_test_envelope(
    snapshot: dict[str, Any],
    *,
    backup_id: str,
    cutoff: datetime,
    key_id: str,
    key: bytes,
    backup_location: str,
    key_location: str,
) -> BackupEnvelope:
    if backup_location == key_location:
        raise ValueError("backup bytes and key authority must not share one location")
    if not key or key.decode("utf-8", errors="ignore") in json.dumps(snapshot):
        raise ValueError("test key must be external to snapshot data")
    payload = _canonical_bytes(snapshot)
    nonce = hashlib.sha256((backup_id + cutoff.isoformat()).encode()).digest()[:12]
    ciphertext = _xor(payload, key, nonce)
    tag = hmac.new(key, nonce + ciphertext, hashlib.sha256).digest()
    return BackupEnvelope(
        backup_id=backup_id,
        cutoff=cutoff,
        key_id=key_id,
        backup_location=backup_location,
        key_location=key_location,
        nonce=nonce,
        ciphertext=ciphertext,
        authentication_tag=tag,
        plaintext_sha256=hashlib.sha256(payload).hexdigest(),
        ciphertext_sha256=hashlib.sha256(ciphertext).hexdigest(),
    )


def validate_business_invariants(snapshot: dict[str, Any]) -> dict[str, int]:
    orders = snapshot.get("work_orders", [])
    histories = snapshot.get("status_history", [])
    receipts = snapshot.get("idempotency_records", [])
    if not all(isinstance(items, list) for items in (orders, histories, receipts)):
        raise ValueError("snapshot tables must be lists")

    order_by_id = {row["id"]: row for row in orders}
    if len(order_by_id) != len(orders):
        raise ValueError("duplicate work-order identity")
    for order_id, order in order_by_id.items():
        if order["status"] not in KNOWN_STATUSES:
            raise ValueError(f"unknown status for {order_id}")
        trail = sorted(
            (row for row in histories if row["work_order_id"] == order_id),
            key=lambda row: row["sequence"],
        )
        if not trail or [row["sequence"] for row in trail] != list(range(1, len(trail) + 1)):
            raise ValueError(f"broken status-history sequence for {order_id}")
        if trail[0]["to_status"] != "CREATED":
            raise ValueError(f"status history does not begin at CREATED for {order_id}")
        for previous, current in zip(trail, trail[1:]):
            if (previous["to_status"], current["to_status"]) not in LEGAL_TRANSITIONS:
                raise ValueError(f"illegal status transition for {order_id}")
        if trail[-1]["to_status"] != order["status"]:
            raise ValueError(f"current status disagrees with history for {order_id}")

    keys = [row["idempotency_key"] for row in receipts]
    if len(keys) != len(set(keys)):
        raise ValueError("duplicate idempotency key")
    if any(row["work_order_id"] not in order_by_id for row in receipts):
        raise ValueError("idempotency receipt points to a missing work order")
    return {
        "work_orders": len(orders),
        "status_history": len(histories),
        "idempotency_records": len(receipts),
    }


def restore_and_measure(
    envelope: BackupEnvelope,
    *,
    key: bytes,
    target: RestoreTarget,
    disaster_at: datetime,
    restore_started_at: datetime,
    restore_finished_at: datetime,
    max_rpo_seconds: float,
    max_rto_seconds: float,
) -> DrillResult:
    if target.environment.lower() in {"prod", "production"}:
        raise ValueError("restore drill must never target production")
    if not target.empty:
        raise ValueError("restore drill target must be disposable and empty")
    if envelope.backup_location == envelope.key_location:
        raise ValueError("key and backup share a failure domain")
    if hashlib.sha256(envelope.ciphertext).hexdigest() != envelope.ciphertext_sha256:
        raise ValueError("ciphertext digest mismatch")
    expected_tag = hmac.new(key, envelope.nonce + envelope.ciphertext, hashlib.sha256).digest()
    if not hmac.compare_digest(expected_tag, envelope.authentication_tag):
        raise ValueError("authentication tag mismatch")

    payload = _xor(envelope.ciphertext, key, envelope.nonce)
    if hashlib.sha256(payload).hexdigest() != envelope.plaintext_sha256:
        raise ValueError("restored payload digest mismatch")
    snapshot = json.loads(payload.decode("utf-8"))
    counts = validate_business_invariants(snapshot)
    rpo = (disaster_at - envelope.cutoff).total_seconds()
    rto = (restore_finished_at - restore_started_at).total_seconds()
    if rpo < 0 or rto < 0:
        raise ValueError("drill timeline is impossible")
    if rpo > max_rpo_seconds:
        raise ValueError(f"RPO missed: {rpo:.0f}s > {max_rpo_seconds:.0f}s")
    if rto > max_rto_seconds:
        raise ValueError(f"RTO missed: {rto:.0f}s > {max_rto_seconds:.0f}s")
    target.empty = False
    return DrillResult(rpo, rto, counts, envelope.plaintext_sha256)


def factorycare_snapshot() -> dict[str, Any]:
    return {
        "work_orders": [
            {"id": "WO-1001", "status": "IN_PROGRESS"},
            {"id": "WO-1002", "status": "CLOSED"},
        ],
        "status_history": [
            {"work_order_id": "WO-1001", "sequence": 1, "to_status": "CREATED"},
            {"work_order_id": "WO-1001", "sequence": 2, "to_status": "TRIAGED"},
            {"work_order_id": "WO-1001", "sequence": 3, "to_status": "ASSIGNED"},
            {"work_order_id": "WO-1001", "sequence": 4, "to_status": "ACCEPTED"},
            {"work_order_id": "WO-1001", "sequence": 5, "to_status": "IN_PROGRESS"},
            {"work_order_id": "WO-1002", "sequence": 1, "to_status": "CREATED"},
            {"work_order_id": "WO-1002", "sequence": 2, "to_status": "TRIAGED"},
            {"work_order_id": "WO-1002", "sequence": 3, "to_status": "ASSIGNED"},
            {"work_order_id": "WO-1002", "sequence": 4, "to_status": "ACCEPTED"},
            {"work_order_id": "WO-1002", "sequence": 5, "to_status": "IN_PROGRESS"},
            {"work_order_id": "WO-1002", "sequence": 6, "to_status": "RESOLVED"},
            {"work_order_id": "WO-1002", "sequence": 7, "to_status": "VERIFIED"},
            {"work_order_id": "WO-1002", "sequence": 8, "to_status": "CLOSED"},
        ],
        "idempotency_records": [
            {"idempotency_key": "submit-1001", "work_order_id": "WO-1001"},
            {"idempotency_key": "close-1002", "work_order_id": "WO-1002"},
        ],
    }


def utc(text: str) -> datetime:
    return datetime.fromisoformat(text).replace(tzinfo=timezone.utc)
