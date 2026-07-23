def cite(source_id: str, source_text: str, answer: str) -> dict[str, object]:
    start = source_text.index(answer)
    return {
        "source_id": source_id,
        "start": start,
        "end": start + len(answer),
        "quote": answer,
    }
