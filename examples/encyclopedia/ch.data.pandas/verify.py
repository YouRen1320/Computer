import platform

import numpy as np
import pandas as pd

from pipeline import build_closed_order_summary

orders = pd.DataFrame(
    {
        "order_id": ["WO-1", "WO-2", "WO-3", "WO-4"],
        "device_id": ["D-1", "D-2", "D-2", "D-9"],
        "technician_id": ["T-1", " T-1 ", pd.NA, "T-2"],
        "duration_raw": ["30", "bad", "45", " 60 "],
        "status": ["CLOSED", "CLOSED", "OPEN", "CLOSED"],
        "closed_at": [
            "2026-07-24T10:00:00+08:00",
            "2026-07-24T02:30:00Z",
            "2026-07-24T03:00:00Z",
            "2026-07-24T04:00:00Z",
        ],
    }
)
devices = pd.DataFrame(
    {
        "device_id": [" d-1 ", "D-2", "D-3"],
        "category": ["pump", "motor", pd.NA],
    }
)
orders_before = orders.copy(deep=True)
devices_before = devices.copy(deep=True)

result = build_closed_order_summary(orders, devices)
pd.testing.assert_frame_equal(orders, orders_before)
pd.testing.assert_frame_equal(devices, devices_before)
assert result.quality == {
    "input_order_rows": 4,
    "closed_order_rows": 3,
    "invalid_duration_rows": 1,
    "invalid_time_rows": 0,
    "unmatched_device_rows": 1,
}
assert result.summary["ticket_count"].sum() == 3

pump = result.summary.loc[result.summary["category"].eq("PUMP")].iloc[0]
assert pump["technician_id"] == "T-1"
assert pump["ticket_count"] == 1
assert pump["valid_duration_count"] == 1
assert pump["mean_duration_min"] == 30.0

motor = result.summary.loc[result.summary["category"].eq("MOTOR")].iloc[0]
assert motor["ticket_count"] == 1
assert motor["valid_duration_count"] == 0
assert pd.isna(motor["mean_duration_min"])

unknown = result.summary.loc[result.summary["category"].isna()].iloc[0]
assert unknown["technician_id"] == "T-2"
assert unknown["mean_duration_min"] == 60.0

duplicate_devices = pd.concat([devices, devices.iloc[[0]]], ignore_index=True)
try:
    build_closed_order_summary(orders, duplicate_devices)
except ValueError as error:
    assert "unique" in str(error)
else:
    raise AssertionError("duplicate dimension keys must fail before merge")

print(
    f"PASS pandas example: Python {platform.python_version()}, "
    f"pandas {pd.__version__}, NumPy {np.__version__}"
)
