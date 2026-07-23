from faults import Output, Source, classify_pipeline, first_failure


SOURCE = Source("manual-1", "故障 E7 的处理方法是断电检查。")


def test_document_only_reference_is_detected_before_entailment_guess() -> None:
    output = Output("断电检查。", "manual-1", None, None)
    assert first_failure(output, (SOURCE,)) == "citation:missing-concrete-span"


def test_no_evidence_answer_is_not_hidden_by_fluent_text() -> None:
    output = Output("请更换主板。", None, None, None)
    assert first_failure(output, ()) == "generation:answered-without-evidence"
    assert classify_pipeline((), output) == {
        "retrieval_succeeded": False,
        "generation_answered": True,
        "citation_valid": False,
    }


def test_correct_looking_answer_with_wrong_span_fails_citation_layer() -> None:
    output = Output("断电检查。", "manual-1", 0, 5)
    assert first_failure(output, (SOURCE,)) == "citation:span-does-not-support-answer"


def test_retrieval_failure_stays_visible_when_generator_refuses() -> None:
    output = Output("证据不足。", None, None, None, refused=True)
    evidence = classify_pipeline((), output)
    assert evidence["retrieval_succeeded"] is False
    assert evidence["citation_valid"] is True
