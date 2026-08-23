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
OWNER = Source(
    source_id="roster-e42-v2",
    text="E42 由值班工程师负责。",
    fact_key="e42.owner",
    fact_value="值班工程师",
)
IRRELEVANT = Source(
    source_id="manual-e99-v1",
    text="E99 需要检查传感器。",
    fact_key="e99.action",
    fact_value="检查传感器。",
)


def test_frozen_regression_separates_answer_retrieval_and_citation() -> None:
    cases = (
        RegressionCase("answerable", "E42 怎么办？", (CURRENT,), "answered",
                       CURRENT.fact_value, frozenset({CURRENT.source_id})),
        RegressionCase("active-but-irrelevant", "E42 怎么办？", (IRRELEVANT,),
                       "insufficient_evidence", None, frozenset({CURRENT.source_id})),
        RegressionCase("unanswerable", "E99 怎么办？", (), "insufficient_evidence",
                       None, frozenset()),
        RegressionCase("conflict", "E42 怎么办？", (CURRENT, CONFLICT),
                       "conflicting_evidence", None,
                       frozenset({CURRENT.source_id, CONFLICT.source_id})),
        RegressionCase("stale-only", "E42 怎么办？", (STALE,),
                       "insufficient_evidence", None, frozenset({STALE.source_id})),
        RegressionCase("different-fact-key-does-not-conflict", "E42 怎么办？",
                       (CURRENT, OWNER), "answered", CURRENT.fact_value,
                       frozenset({CURRENT.source_id})),
    )
    metrics = evaluate(cases)
    assert metrics == {
        "case_count": 6,
        "retrieval_judged_count": 5,
        "retrieval_hit_count": 3,
        "retrieval_hit_rate": 0.6,
        "answerable_case_count": 2,
        "answer_correctness": 1.0,
        "refusal_case_count": 4,
        "refusal_recall": 1.0,
        "status_accuracy": 1.0,
        "answered_case_count": 2,
        "cited_answer_count": 2,
        "citation_count": 2,
        "citation_structure_validity": 1.0,
        "citation_precision": 1.0,
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


def test_non_answer_without_citation_is_not_counted_as_a_valid_citation() -> None:
    case = RegressionCase("unanswerable", "E99 怎么办？", (),
                          "insufficient_evidence", None, frozenset())
    metrics = evaluate((case,))
    assert metrics["answered_case_count"] == 0
    assert metrics["citation_count"] == 0
    assert metrics["citation_structure_validity"] is None
    assert metrics["citation_precision"] is None
