from pipeline import Document, chunk, mock_embed


def test_chunks_keep_parent_acl_and_fixed_embedding_dimension() -> None:
    document = Document("manual-7", "parent-hash", "E42 告警", ("检查电源。", "复位设备。"), ("tenant:A", "role:tech"))
    first = chunk(document, 20)
    second = chunk(document, 20)
    assert first == second
    assert all(item["parent_id"] == "manual-7" and item["acl"] == document.acl for item in first)
    vectors = [mock_embed(str(item["text"])) for item in first]
    assert [len(vector) for vector in vectors] == [4, 4]
