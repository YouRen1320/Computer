from ingest import ingest


def test_acl_and_source_are_atomic_with_text() -> None:
    output = ingest({"document_id": "m1", "text": "repair", "source_uri": "kb://m1", "acl": ("tenant:A",)})
    assert output["source_uri"] == "kb://m1"
    assert output["acl"] == ("tenant:A",)
