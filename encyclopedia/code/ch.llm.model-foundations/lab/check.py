from budget import Segment, StageEvidence, fit_context, validate_stage_evidence

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

valid_pipeline = [
    StageEvidence("embedding", "vector", False),
    StageEvidence("inference", "text-or-token-distribution", False),
    StageEvidence("training", "loss-and-gradients", True),
]
assert validate_stage_evidence(valid_pipeline) == []
invalid_pipeline = [
    StageEvidence("embedding", "generated-text", False),
    StageEvidence("inference", "text-or-token-distribution", True),
]
assert validate_stage_evidence(invalid_pipeline) == [
    "embedding output must be vector, not generated-text",
    "inference updates_weights must be False",
]
print("deterministic context budget, truncation record and model-stage boundaries: PASS")
