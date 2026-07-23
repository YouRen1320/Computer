from citation import cite


def test_private_solution_returns_exact_span() -> None:
    source = "E42 表示过热。处理：先停机。随后检查冷却回路。"
    start = source.index("先停机。")
    assert cite("manual-e42", source, "先停机。") == {
        "source_id": "manual-e42",
        "start": start,
        "end": start + len("先停机。"),
        "quote": "先停机。",
    }
