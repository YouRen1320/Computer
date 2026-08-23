from __future__ import annotations

from dataclasses import dataclass

import pandas as pd


@dataclass(frozen=True)
class SummaryResult:
    summary: pd.DataFrame
    quality: dict[str, int]


def _require_columns(frame: pd.DataFrame, required: set[str], label: str) -> None:
    missing = required - set(frame.columns)
    if missing:
        raise ValueError(f"{label} missing columns: {sorted(missing)}")


def _clean_id(series: pd.Series) -> pd.Series:
    cleaned = series.astype("string").str.strip().str.upper()
    return cleaned.mask(cleaned.eq(""), pd.NA)


def build_closed_order_summary(
    orders: pd.DataFrame,
    devices: pd.DataFrame,
) -> SummaryResult:
    order_columns = {
        "order_id",
        "device_id",
        "technician_id",
        "duration_raw",
        "status",
        "closed_at",
    }
    device_columns = {"device_id", "category"}
    _require_columns(orders, order_columns, "orders")
    _require_columns(devices, device_columns, "devices")

    clean_orders = orders.loc[:, sorted(order_columns)].copy()
    clean_devices = devices.loc[:, sorted(device_columns)].copy()

    for column in ("order_id", "device_id", "technician_id"):
        clean_orders[column] = _clean_id(clean_orders[column])
    clean_orders["status"] = _clean_id(clean_orders["status"])
    clean_devices["device_id"] = _clean_id(clean_devices["device_id"])
    clean_devices["category"] = _clean_id(clean_devices["category"])

    if clean_orders["order_id"].isna().any():
        raise ValueError("order_id must not be missing")
    if not clean_orders["order_id"].is_unique:
        raise ValueError("order_id must be unique")
    if clean_devices["device_id"].isna().any():
        raise ValueError("device dimension key must not be missing")
    if not clean_devices["device_id"].is_unique:
        raise ValueError("device dimension key must be unique")

    duration_text = clean_orders["duration_raw"].astype("string").str.strip()
    duration = pd.to_numeric(duration_text, errors="coerce")
    invalid_duration = (
        (duration_text.notna() & duration_text.ne("") & duration.isna())
        | duration.lt(0).fillna(False)
    )
    duration = duration.mask(invalid_duration, pd.NA).astype("Float64")
    clean_orders["duration_min"] = duration

    closed_text = clean_orders["closed_at"].astype("string").str.strip()
    closed_at = pd.to_datetime(closed_text, format="mixed", errors="coerce", utc=True)
    invalid_time = closed_text.notna() & closed_text.ne("") & closed_at.isna()
    clean_orders["closed_at_utc"] = closed_at

    closed = clean_orders.loc[clean_orders["status"].eq("CLOSED")].copy()
    merged = closed.merge(
        clean_devices,
        how="left",
        on="device_id",
        validate="many_to_one",
        indicator=True,
    )
    if len(merged) != len(closed):
        raise AssertionError("many-to-one left join changed row count")

    summary = (
        merged.groupby(
            ["category", "technician_id"],
            dropna=False,
            as_index=False,
        )
        .agg(
            ticket_count=("order_id", "size"),
            valid_duration_count=("duration_min", "count"),
            mean_duration_min=("duration_min", "mean"),
        )
        .sort_values(["category", "technician_id"], na_position="last")
        .reset_index(drop=True)
    )

    return SummaryResult(
        summary=summary,
        quality={
            "input_order_rows": len(clean_orders),
            "closed_order_rows": len(closed),
            "invalid_duration_rows": int(invalid_duration.sum()),
            "invalid_time_rows": int(invalid_time.sum()),
            "unmatched_device_rows": int(merged["_merge"].eq("left_only").sum()),
        },
    )
