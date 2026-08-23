from ingest import broken_ingest


def test_acl_and_source_are_atomic_with_text() -> None:
    output = broken_ingest({"document_id": "m1", "text": "repair", "source_uri": "kb://m1", "acl": ("tenant:A",)})
    assert output["source_uri"] == "kb://m1" and output["acl"] == ("tenant:A",), "ACL and source lineage must travel with normalized text"
