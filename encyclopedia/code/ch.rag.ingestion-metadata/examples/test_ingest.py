from ingest import Source, ingest


def test_normalized_document_keeps_lineage_and_acl() -> None:
    source = Source("manual-1", "kb://factorycare/manual-1", "rev-7", ("tenant:demo", "role:tech"), "# 标题\r\n正文  \r\n")
    first = ingest(source)
    second = ingest(source)
    assert first == second
    assert first["source_uri"] == "kb://factorycare/manual-1"
    assert first["acl"] == ("tenant:demo", "role:tech")
    assert first["normalized_text"] == "# 标题\n正文\n"
