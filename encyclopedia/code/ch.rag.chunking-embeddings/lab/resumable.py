from collections.abc import Callable


def run(
    chunks: list[dict[str, object]],
    completed: dict[str, list[float]],
    embed: Callable[[str], list[float]],
    expected_dimension: int,
) -> dict[str, list[float]]:
    result = dict(completed)
    for item in chunks:
        chunk_id = str(item["chunk_id"])
        if chunk_id in result:
            continue
        if not item.get("parent_id") or not item.get("acl"):
            raise ValueError("chunk lineage and ACL are required")
        vector = embed(str(item["text"]))
        if len(vector) != expected_dimension:
            raise ValueError(f"embedding dimension mismatch for {chunk_id}")
        result[chunk_id] = vector
    return result
