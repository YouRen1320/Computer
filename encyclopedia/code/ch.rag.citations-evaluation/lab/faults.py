from dataclasses import dataclass


@dataclass(frozen=True)
class Source:
    source_id: str
    text: str


@dataclass(frozen=True)
class Output:
    answer: str
    source_id: str | None
    start: int | None
    end: int | None
    refused: bool = False


def first_failure(output: Output, retrieved: tuple[Source, ...]) -> str | None:
    if not retrieved:
        return None if output.refused else "generation:answered-without-evidence"
    if output.refused:
        return "generation:refused-despite-retrieved-evidence"
    if output.source_id is None or output.start is None or output.end is None:
        return "citation:missing-concrete-span"
    source = next((item for item in retrieved if item.source_id == output.source_id), None)
    if source is None:
        return "citation:source-not-retrieved"
    if not (0 <= output.start < output.end <= len(source.text)):
        return "citation:span-out-of-range"
    if output.answer not in source.text[output.start : output.end]:
        return "citation:span-does-not-support-answer"
    return None


def classify_pipeline(retrieved: tuple[Source, ...], output: Output) -> dict[str, bool]:
    """Keep retrieval, generation and citation evidence independently visible."""
    return {
        "retrieval_succeeded": bool(retrieved),
        "generation_answered": not output.refused,
        "citation_valid": first_failure(output, retrieved) is None,
    }
