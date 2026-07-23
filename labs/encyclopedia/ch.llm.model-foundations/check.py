from budget import Segment, fit_context

segments = [
    Segment("system", 12, True),
    Segment("question", 8, True),
    Segment("document-1", 20, False),
    Segment("document-2", 15, False),
]
kept, dropped = fit_context(segments, context_limit=64, output_reserve=12, overhead=4)
assert [item.name for item in kept] == ["system", "question", "document-1"]
assert dropped == ["document-2"]
assert sum(item.token_count for item in kept) + 12 + 4 <= 64
print("deterministic context budget and truncation record: PASS")
