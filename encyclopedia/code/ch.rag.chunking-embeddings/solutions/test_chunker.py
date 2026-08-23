from chunker import chunks


def test_every_chunk_inherits_parent_and_acl() -> None:
    document = {"document_id": "d1", "acl": ("tenant:A",), "paragraphs": ("one", "two")}
    output = chunks(document)
    assert all(item["parent_id"] == "d1" and item["acl"] == ("tenant:A",) for item in output)
