import pandas as pd

dirty = pd.DataFrame({"duration": ["10", "bad", "30"]})
converted = pd.to_numeric(dirty["duration"], errors="coerce")
invalid = dirty["duration"].notna() & converted.isna()
assert invalid.tolist() == [False, True, False]
assert converted.isna().sum() == 1

missing = pd.Series(["T-1", pd.NA, ""], dtype="string")
assert missing.isna().tolist() == [False, True, False]
normalized = missing.mask(missing.eq(""), pd.NA)
assert normalized.isna().tolist() == [False, True, True]

frame = pd.DataFrame({"duration": [10.0, -1.0, 20.0]})
derived = frame.loc[frame["duration"].lt(0)].copy()
derived.loc[:, "duration"] = 0.0
assert frame.loc[1, "duration"] == -1.0
frame.loc[frame["duration"].lt(0), "duration"] = float("nan")
assert pd.isna(frame.loc[1, "duration"])

left = pd.DataFrame({"device_id": ["D-1", "D-1"], "order_id": ["WO-1", "WO-2"]})
right = pd.DataFrame({"device_id": ["D-1", "D-1"], "category": ["PUMP", "PUMP-OLD"]})
exploded = left.merge(right, on="device_id")
assert len(exploded) == 4
try:
    left.merge(right, on="device_id", validate="many_to_one")
except pd.errors.MergeError:
    pass
else:
    raise AssertionError("many_to_one validation must reject duplicate right keys")

unique_right = right.drop_duplicates("device_id", keep="first")
fixed = left.merge(unique_right, on="device_id", validate="many_to_one")
assert len(fixed) == len(left) == 2

print("PASS pandas lab: dtype, missing, CoW and cardinality faults reproduced")
