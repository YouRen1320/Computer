import pandas as pd

from manifest import assert_manifest, build_manifest


def test_grouped_temporal_manifest() -> None:
    frame = pd.DataFrame(
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
    manifest = build_manifest(frame)
    assert manifest["split"].astype(str).tolist() == ["train", "validation", "test"]
    assert_manifest(manifest)
