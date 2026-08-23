from citation import cite


def test_citation_is_the_smallest_exact_supporting_span() -> None:
    source = "E42 表示过热。处理：先停机。随后检查冷却回路。"
    result = cite("manual-e42", source, "先停机。")
    start = source.index("先停机。")
    assert result == {
        "source_id": "manual-e42",
        "start": start,
        "end": start + len("先停机。"),
        "quote": "先停机。",
    }
