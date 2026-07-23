from grounded_rag import (
    Citation,
    FrozenGroundedGenerator,
    GroundedAnswer,
    RegressionCase,
    Source,
    assemble_context,
    audit_answer,
    evaluate,
)


CURRENT = Source(
    source_id="manual-e42-v3",
    text="E42 表示冷却液温度过高。先停机并检查冷却回路。",
    fact_key="e42.action",
    fact_value="先停机并检查冷却回路。",
)
CONFLICT = Source(
    source_id="bulletin-e42-v4",
    text="E42 新规要求保持低速运行并联系值班工程师。",
    fact_key="e42.action",
    fact_value="保持低速运行并联系值班工程师。",
)
STALE = Source(
    source_id="manual-e42-v1",
    text="旧版说明：E42 出现后可继续运行。",
    fact_key="e42.action",
    fact_value="可继续运行。",
    active=False,
)


def test_frozen_regression_separates_answer_retrieval_and_citation() -> None:
    cases = (
        RegressionCase("answerable", "E42 怎么办？", (CURRENT,), "answered", CURRENT.fact_value),
        RegressionCase("unanswerable", "E99 怎么办？", (), "insufficient_evidence", None),
        RegressionCase("conflict", "E42 怎么办？", (CURRENT, CONFLICT), "conflicting_evidence", None),
        RegressionCase("stale-only", "E42 怎么办？", (STALE,), "insufficient_evidence", None),
    )
    metrics = evaluate(cases)
    assert metrics == {
        "case_count": 4,
        "retrieval_hit_count": 2,
        "answer_correctness": 1.0,
        "citation_validity": 1.0,
    }


def test_answer_contains_exact_span_from_active_context() -> None:
    model = FrozenGroundedGenerator()
    answer = model.generate("E42 怎么办？", (CURRENT,))
    assert answer.status == "answered"
    assert not audit_answer(answer, (CURRENT,))
    citation = answer.citations[0]
    assert CURRENT.text[citation.start : citation.end] == answer.text
    assert "SOURCE manual-e42-v3" in assemble_context((CURRENT, STALE))
    assert "manual-e42-v1" not in assemble_context((CURRENT, STALE))


def test_correct_text_with_wrong_span_is_still_a_citation_failure() -> None:
    wrong = GroundedAnswer(
        status="answered",
        text=CURRENT.fact_value,
        citations=(Citation(source_id=CURRENT.source_id, start=0, end=3, quote="E42"),),
    )
    assert audit_answer(wrong, (CURRENT,)) == ["citation-does-not-entail-answer"]
