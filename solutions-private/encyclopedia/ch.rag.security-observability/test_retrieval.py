from retrieval import Document, candidates_for_model


def test_private_solution_filters_before_model() -> None:
    docs = (
        Document("A-1", "tenant-A", "allowed"),
        Document("B-1", "tenant-B", "secret"),
    )
    assert candidates_for_model("tenant-A", docs) == (docs[0],)
