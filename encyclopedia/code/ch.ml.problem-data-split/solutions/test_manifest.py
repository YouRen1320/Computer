from manifest import grouped_manifest


def test_entities_do_not_cross_splits() -> None:
    manifest = grouped_manifest()
    assert manifest["sample_id"].is_unique
    assert manifest.groupby("entity_id")["split"].nunique().max() == 1
