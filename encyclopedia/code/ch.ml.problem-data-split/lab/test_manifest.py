import pandas as pd
import pytest

from manifest import PROBLEM_CARD, assert_manifest, assert_problem_card, build_manifest


def source_frame() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "sample_id": [11, 12, 13],
            "entity_id": [101, 102, 103],
            "cutoff_at": [
                "2026-01-01T00:00:00Z",
                "2026-03-15T00:00:00Z",
                "2026-04-15T00:00:00Z",
            ],
            "label_ready_at": [
                "2026-01-03T00:00:00Z",
                "2026-03-17T00:00:00Z",
                "2026-04-17T00:00:00Z",
            ],
        }
    )


def test_grouped_temporal_manifest() -> None:
    assert_problem_card(PROBLEM_CARD)
    manifest = build_manifest(source_frame())
    assert manifest["split"].astype(str).tolist() == ["train", "validation", "test"]
    assert_manifest(manifest, {"category", "priority", "age_minutes"})


def test_post_outcome_feature_is_rejected() -> None:
    manifest = build_manifest(source_frame())
    with pytest.raises(AssertionError, match="leak the target"):
        assert_manifest(manifest, {"category", "closed_at"})


def test_one_entity_cannot_cross_splits() -> None:
    frame = source_frame()
    frame.loc[2, "entity_id"] = 101
    with pytest.raises(AssertionError):
        assert_manifest(build_manifest(frame), {"category"})


def test_problem_card_requires_train_only_preprocessing() -> None:
    card = dict(PROBLEM_CARD, preprocessing_fit_scope="fit-before-split")
    with pytest.raises(AssertionError):
        assert_problem_card(card)
