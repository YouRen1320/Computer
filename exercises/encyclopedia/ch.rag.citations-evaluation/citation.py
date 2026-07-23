def cite(source_id: str, source_text: str, answer: str) -> dict[str, object]:
    # TODO: return the exact supporting character interval, not a document-only pointer.
    return {"source_id": source_id, "start": 0, "end": len(source_text), "quote": source_text}
