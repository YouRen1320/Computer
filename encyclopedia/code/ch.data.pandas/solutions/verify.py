import pandas as pd

from solution import safe_enrich

orders = pd.DataFrame({"order_id": ["WO-1", "WO-2"], "device_id": ["D-1", "D-9"]})
devices = pd.DataFrame({"device_id": ["D-1"], "category": ["PUMP"]})
actual = safe_enrich(orders, devices)
assert len(actual) == 2
assert actual["_merge"].astype("string").tolist() == ["both", "left_only"]

duplicates = pd.concat([devices, devices], ignore_index=True)
try:
    safe_enrich(orders, duplicates)
except pd.errors.MergeError:
    pass
else:
    raise AssertionError("duplicate right keys must fail")
print("PASS pandas private solution")
