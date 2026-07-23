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
print("PASS pandas public exercise")
