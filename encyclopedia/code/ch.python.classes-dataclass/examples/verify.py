from dataclasses import FrozenInstanceError

from model import (
    PriorityPolicy,
    PrioritySuggestion,
    ReviewQueue,
    SuggestionService,
    SuggestionStatus,
)

first = PrioritySuggestion(
    order_id="WO-1",
    level=4,
    reasons=("  safety   risk  ",),
)
second = PrioritySuggestion(
    order_id="WO-1",
    level=4,
    reasons=("safety risk",),
)
assert first == second and first is not second
assert first.reasons == ("safety risk",)

try:
    first.level = 2  # type: ignore[misc]
except FrozenInstanceError:
    pass
else:
    raise AssertionError("frozen field assignment must fail")

left_queue = ReviewQueue()
right_queue = ReviewQueue()
left_queue.items.append("WO-1")
assert right_queue.items == []
assert left_queue.items is not right_queue.items

service = SuggestionService(PriorityPolicy())
assert service.suggest(
    order_id="WO-2", severity=4, safety_risk=True
).level == 5
assert getattr(service.suggest, "__self__", None) is service

for build in (
    lambda: PrioritySuggestion(order_id="bad", level=2),
    lambda: PrioritySuggestion(order_id="WO-3", level=0),
    lambda: SuggestionStatus("UNKNOWN"),
):
    try:
        build()
    except ValueError:
        continue
    raise AssertionError("invalid object construction must fail")

print("PASS classes/dataclass example: invariants, binding, equality and isolation hold")
