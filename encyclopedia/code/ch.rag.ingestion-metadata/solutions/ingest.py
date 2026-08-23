def ingest(source: dict[str, object]) -> dict[str, object]:
    if not source.get("source_uri") or not source.get("acl"):
        raise ValueError("source URI and ACL are required")
    return {
        "document_id": source["document_id"],
        "text": source["text"],
        "source_uri": source["source_uri"],
        "acl": source["acl"],
    }
