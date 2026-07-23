from chunker import broken_chunks


def test_every_chunk_inherits_parent_and_acl() -> None:
    document = {"document_id": "d1", "acl": ("tenant:A",), "paragraphs": ("one", "two")}
    chunks = broken_chunks(document)
    assert all(item.get("parent_id") == "d1" and item.get("acl") == ("tenant:A",) for item in chunks), "chunk ACL and parent lineage must be inherited atomically"
