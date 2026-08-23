from solution import PrioritySuggestion

assert PrioritySuggestion(order_id="WO-1", level=5).level == 5
for values in (
    {"order_id": "bad", "level": 2},
    {"order_id": "WO-2", "level": 0},
    {"order_id": "WO-3", "level": 6},
):
    try:
        PrioritySuggestion(**values)
    except ValueError:
        continue
    raise AssertionError(f"illegal state accepted: {values}")
print("PASS classes/dataclass private solution")
