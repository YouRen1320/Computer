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
    relevant_source_ids: frozenset[str]


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
        requested_fact_key = question_fact_key(question)
        eligible = tuple(
            source for source in sources
            if source.active and source.fact_key == requested_fact_key
        )
        if not eligible:
            return GroundedAnswer(
                status="insufficient_evidence",
                text="证据不足，无法回答。",
            )

        values = {source.fact_value for source in eligible}
        if len(values) != 1:
            return GroundedAnswer(
                status="conflicting_evidence",
                text="来源存在冲突，需要人工确认。",
            )

        source = eligible[0]
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


def question_fact_key(question: str) -> str:
    """A frozen query classifier for this fixture, not a general language model."""
    if "E42" in question and any(word in question for word in ("怎么办", "action")):
        return "e42.action"
    if "E42" in question and any(word in question for word in ("负责", "owner")):
        return "e42.owner"
    return "unmatched"


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


def _citation_failures(citation: Citation, answer_text: str,
                       active_by_id: dict[str, Source]) -> tuple[list[str], bool]:
    failures: list[str] = []
    source = active_by_id.get(citation.source_id)
    if source is None:
        return ["citation-source-not-in-active-context"], False
    if citation.end > len(source.text):
        return ["citation-out-of-range"], False
    actual = source.text[citation.start : citation.end]
    if actual != citation.quote:
        return ["citation-quote-mismatch"], False
    entails = actual == answer_text
    if not entails:
        failures.append("citation-does-not-entail-answer")
    return failures, entails


def evaluate(cases: tuple[RegressionCase, ...], *, model=None) -> dict[str, float | int | None]:
    model = model or FrozenGroundedGenerator()
    retrieval_judged = retrieval_hits = 0
    answerable = answer_correct = 0
    refusal_cases = correct_refusals = status_correct = 0
    answered = cited_answers = total_citations = structurally_valid = entailing = 0
    for case in cases:
        active = tuple(source for source in case.retrieved if source.active)
        if case.relevant_source_ids:
            retrieval_judged += 1
        if case.relevant_source_ids & {source.source_id for source in active}:
            retrieval_hits += 1
        answer = model.generate(case.question, case.retrieved)
        expected = answer.status == case.expected_status and (
            case.expected_value is None or answer.text == case.expected_value)
        if expected:
            status_correct += 1
        if case.expected_status == "answered":
            answerable += 1
            if expected:
                answer_correct += 1
        else:
            refusal_cases += 1
            if expected:
                correct_refusals += 1
        if answer.status == "answered":
            answered += 1
            if answer.citations:
                cited_answers += 1
        active_by_id = {source.source_id: source for source in active}
        for citation in answer.citations:
            total_citations += 1
            failures, entails = _citation_failures(citation, answer.text, active_by_id)
            if not any(failure != "citation-does-not-entail-answer" for failure in failures):
                structurally_valid += 1
            if entails:
                entailing += 1
    total = len(cases)
    return {
        "case_count": total,
        "retrieval_judged_count": retrieval_judged,
        "retrieval_hit_count": retrieval_hits,
        "retrieval_hit_rate": retrieval_hits / retrieval_judged if retrieval_judged else None,
        "answerable_case_count": answerable,
        "answer_correctness": answer_correct / answerable if answerable else None,
        "refusal_case_count": refusal_cases,
        "refusal_recall": correct_refusals / refusal_cases if refusal_cases else None,
        "status_accuracy": status_correct / total if total else None,
        "answered_case_count": answered,
        "cited_answer_count": cited_answers,
        "citation_count": total_citations,
        "citation_structure_validity": (
            structurally_valid / total_citations if total_citations else None
        ),
        "citation_precision": entailing / total_citations if total_citations else None,
    }
