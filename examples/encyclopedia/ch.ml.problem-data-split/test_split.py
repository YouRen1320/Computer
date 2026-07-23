import pandas as pd

from split import temporal_split


def test_temporal_manifest_is_exclusive_and_ordered() -> None:
    frame = pd.DataFrame(
        {
            "sample_id": [1, 2, 3, 4],
            "cutoff_at": [
                "2026-01-01T00:00:00Z",
                "2026-02-01T00:00:00Z",
                "2026-03-01T00:00:00Z",
                "2026-04-01T00:00:00Z",
            ],
        }
    )
    result = temporal_split(frame)

    assert result["sample_id"].is_unique
    assert result["split"].tolist() == ["train", "validation", "test", "test"]
    assert result.groupby("sample_id")["split"].nunique().max() == 1
