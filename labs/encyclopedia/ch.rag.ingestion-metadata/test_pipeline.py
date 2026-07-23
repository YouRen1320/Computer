from pipeline import InputDocument, run


def test_valid_markdown_pdf_text_fixture_and_quarantine() -> None:
    inputs = [
        InputDocument("md-1", "git://manual.md", "a1", "text/markdown", ("tenant:A",), "# Manual\nBody"),
        InputDocument("pdf-1", "docs://manual.pdf", "7", "application/pdf-extracted-text", ("tenant:A", "role:tech"), "[page=1]\nPump"),
        InputDocument("bad-1", "docs://broken.pdf", "2", "application/pdf", ("tenant:A",), None),
    ]
    first = run(inputs)
    second = run(inputs)
    published, quarantine = first
    assert first == second
    assert len(published) == 2
    assert len(quarantine) == 1 and quarantine[0]["error"] == "parse_failed"
    assert all(item["source_uri"] and item["acl"] and item["hash"] for item in published)


def test_missing_acl_is_quarantined_not_public() -> None:
    published, quarantine = run([InputDocument("secret", "kb://secret", "1", "text/plain", (), "classified")])
    assert published == []
    assert quarantine[0]["error"] == "missing_acl"
