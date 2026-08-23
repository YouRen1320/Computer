from dataclasses import dataclass


@dataclass(frozen=True)
class Segment:
    name: str
    token_count: int
    required: bool


@dataclass(frozen=True)
class StageEvidence:
    stage: str
    output_kind: str
    updates_weights: bool


STAGE_CONTRACTS = {
    "embedding": ("vector", False),
    "inference": ("text-or-token-distribution", False),
    "training": ("loss-and-gradients", True),
}


def validate_stage_evidence(evidence: list[StageEvidence]) -> list[str]:
    """Check stage boundaries without pretending to execute a real model."""
    errors: list[str] = []
    for item in evidence:
        contract = STAGE_CONTRACTS.get(item.stage)
        if contract is None:
            errors.append(f"unknown stage: {item.stage}")
            continue
        expected_output, expected_update = contract
        if item.output_kind != expected_output:
            errors.append(f"{item.stage} output must be {expected_output}, not {item.output_kind}")
        if item.updates_weights is not expected_update:
            errors.append(f"{item.stage} updates_weights must be {expected_update}")
    return errors


def fit_context(segments: list[Segment], context_limit: int, output_reserve: int, overhead: int) -> tuple[list[Segment], list[str]]:
    available = context_limit - output_reserve - overhead
    if available < 0:
        raise ValueError("reserves exceed context limit")
    kept: list[Segment] = []
    dropped: list[str] = []
    used = 0
    for segment in segments:
        if used + segment.token_count <= available:
            kept.append(segment)
            used += segment.token_count
        elif segment.required:
            raise ValueError(f"required segment does not fit: {segment.name}")
        else:
            dropped.append(segment.name)
    return kept, dropped
