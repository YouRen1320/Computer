from manifest import broken_manifest


def test_entities_do_not_cross_splits() -> None:
    manifest = broken_manifest()
    entity_split_count = manifest.groupby("entity_id")["split"].nunique()
    assert entity_split_count.max() == 1, "entity leakage: one entity appears in multiple splits"
