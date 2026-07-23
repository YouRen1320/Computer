from resumable import run


def test_resume_skips_completed_and_preserves_shape() -> None:
    calls: list[str] = []

    def embed(text: str) -> list[float]:
        calls.append(text)
        return [float(len(text)), 1.0, 0.0]

    chunks = [
        {"chunk_id": "c1", "parent_id": "d1", "acl": ("tenant:A",), "text": "first"},
        {"chunk_id": "c2", "parent_id": "d1", "acl": ("tenant:A",), "text": "second"},
    ]
    output = run(chunks, {"c1": [5.0, 1.0, 0.0]}, embed, 3)
    assert calls == ["second"]
    assert set(output) == {"c1", "c2"}
    assert all(len(vector) == 3 for vector in output.values())


def test_dimension_mismatch_fails_before_publish() -> None:
    chunks = [{"chunk_id": "bad", "parent_id": "d", "acl": ("tenant:A",), "text": "x"}]
    try:
        run(chunks, {}, lambda _: [1.0, 2.0], 3)
    except ValueError as error:
        assert "dimension mismatch" in str(error)
    else:
        raise AssertionError("dimension mismatch must fail")
