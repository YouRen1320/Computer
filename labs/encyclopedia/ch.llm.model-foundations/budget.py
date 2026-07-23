from dataclasses import dataclass


@dataclass(frozen=True)
class Segment:
    name: str
    token_count: int
    required: bool


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
