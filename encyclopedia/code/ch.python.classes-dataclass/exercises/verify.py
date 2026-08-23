from starter import PrioritySuggestion

assert PrioritySuggestion(order_id="WO-1", level=5).level == 5
for values in (
    {"order_id": "bad", "level": 2},
    {"order_id": "WO-2", "level": 0},
):
    try:
        PrioritySuggestion(**values)
    except ValueError:
        continue
    raise AssertionError(f"illegal state accepted: {values}; complete TODO")
print("PASS classes/dataclass public exercise")
