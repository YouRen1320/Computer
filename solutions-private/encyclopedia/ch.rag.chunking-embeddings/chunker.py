def chunks(document: dict[str, object]) -> list[dict[str, object]]:
    return [
        {
            "chunk_id": f"{document['document_id']}:{index}",
            "parent_id": document["document_id"],
            "acl": document["acl"],
            "text": text,
        }
        for index, text in enumerate(document["paragraphs"])
    ]
