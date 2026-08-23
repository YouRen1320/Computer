import pandas as pd

from starter import safe_enrich

orders = pd.DataFrame({"order_id": ["WO-1", "WO-2"], "device_id": ["D-1", "D-1"]})
duplicate_devices = pd.DataFrame(
    {"device_id": ["D-1", "D-1"], "category": ["PUMP", "PUMP-OLD"]}
)
try:
    safe_enrich(orders, duplicate_devices)
except pd.errors.MergeError:
    pass
else:
    raise AssertionError("duplicate dimension keys must be rejected; complete TODO")

valid_orders = pd.DataFrame({
    "order_id": ["WO-1", "WO-2"],
    "device_id": ["D-1", "D-9"],
})
valid_devices = pd.DataFrame({"device_id": ["D-1"], "category": ["PUMP"]})
actual = safe_enrich(valid_orders, valid_devices)
assert len(actual) == len(valid_orders)
assert actual["order_id"].tolist() == ["WO-1", "WO-2"]
assert actual["category"].astype("string").fillna("MISSING").tolist() == ["PUMP", "MISSING"]
assert actual["_merge"].astype("string").tolist() == ["both", "left_only"]
print("PASS pandas public exercise")
