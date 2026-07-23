from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class Source(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    source_id: str
    text: str
    fact_key: str
    fact_value: str
    active: bool = True


class Citation(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    source_id: str
    start: int = Field(ge=0)
    end: int = Field(gt=0)
    quote: str

    @model_validator(mode="after")
    def end_follows_start(self) -> "Citation":
        if self.end <= self.start:
            raise ValueError("citation end must be greater than start")
        return self


class GroundedAnswer(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    status: Literal["answered", "insufficient_evidence", "conflicting_evidence"]
    text: str
    citations: tuple[Citation, ...] = ()


@dataclass(frozen=True)
class RegressionCase:
    name: str
    question: str
    retrieved: tuple[Source, ...]
    expected_status: str
    expected_value: str | None


def assemble_context(sources: tuple[Source, ...]) -> str:
    """Keep source identity visible; context formatting never grants authority."""
    return "\n\n".join(
        f"SOURCE {source.source_id}\n{source.text}"
        for source in sources
        if source.active
    )


class FrozenGroundedGenerator:
    """Deterministic model substitute: no network or model API is contacted."""

    def generate(self, question: str, sources: tuple[Source, ...]) -> GroundedAnswer:
        del question  # The frozen fixture evaluates evidence handling, not language quality.
        active = tuple(source for source in sources if source.active)
        if not active:
            return GroundedAnswer(
                status="insufficient_evidence",
                text="证据不足，无法回答。",
            )

        values = {source.fact_value for source in active}
        if len(values) != 1:
            return GroundedAnswer(
                status="conflicting_evidence",
                text="来源存在冲突，需要人工确认。",
            )

        source = active[0]
        claim = source.fact_value
        start = source.text.index(claim)
        return GroundedAnswer(
            status="answered",
            text=claim,
            citations=(
                Citation(
                    source_id=source.source_id,
                    start=start,
                    end=start + len(claim),
                    quote=claim,
                ),
            ),
        )


def audit_answer(answer: GroundedAnswer, retrieved: tuple[Source, ...]) -> list[str]:
    by_id = {source.source_id: source for source in retrieved if source.active}
    failures: list[str] = []

    if answer.status != "answered":
        if answer.citations:
            failures.append("non-answer-must-not-cite")
        return failures
    if not answer.citations:
        return ["answered-without-citation"]

    supported_fragments: list[str] = []
    for citation in answer.citations:
        source = by_id.get(citation.source_id)
        if source is None:
            failures.append("citation-source-not-in-active-context")
            continue
        if citation.end > len(source.text):
            failures.append("citation-out-of-range")
            continue
        actual = source.text[citation.start : citation.end]
        if actual != citation.quote:
            failures.append("citation-quote-mismatch")
            continue
        supported_fragments.append(actual)

    if answer.text not in supported_fragments:
        failures.append("citation-does-not-entail-answer")
    return failures


def evaluate(cases: tuple[RegressionCase, ...]) -> dict[str, float | int]:
    model = FrozenGroundedGenerator()
    retrieval_hits = answer_correct = citation_valid = 0
    for case in cases:
        active = tuple(source for source in case.retrieved if source.active)
        if active:
            retrieval_hits += 1
        answer = model.generate(case.question, case.retrieved)
        if answer.status == case.expected_status and (
            case.expected_value is None or answer.text == case.expected_value
        ):
            answer_correct += 1
        if not audit_answer(answer, case.retrieved):
            citation_valid += 1
    total = len(cases)
    return {
        "case_count": total,
        "retrieval_hit_count": retrieval_hits,
        "answer_correctness": answer_correct / total,
        "citation_validity": citation_valid / total,
    }
