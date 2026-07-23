import pandas as pd


FORBIDDEN_FEATURES = {"closed_at", "final_status", "resolution_note"}


def build_manifest(frame: pd.DataFrame) -> pd.DataFrame:
    data = frame.copy()
    data["cutoff_at"] = pd.to_datetime(data["cutoff_at"], utc=True)
    data["label_ready_at"] = pd.to_datetime(data["label_ready_at"], utc=True)
    data = data.sort_values(["cutoff_at", "sample_id"], kind="stable")
    data["split"] = pd.cut(
        data["cutoff_at"],
        bins=[pd.Timestamp.min.tz_localize("UTC"), pd.Timestamp("2026-03-01", tz="UTC"), pd.Timestamp("2026-04-01", tz="UTC"), pd.Timestamp.max.tz_localize("UTC")],
        labels=["train", "validation", "test"],
        right=False,
    )
    return data[["sample_id", "entity_id", "cutoff_at", "label_ready_at", "split"]]


def assert_manifest(manifest: pd.DataFrame) -> None:
    assert manifest["sample_id"].is_unique
    assert not manifest["split"].isna().any()
    groups = {name: set(part["entity_id"]) for name, part in manifest.groupby("split", observed=True)}
    assert groups["train"].isdisjoint(groups["validation"])
    assert groups["train"].isdisjoint(groups["test"])
    assert groups["validation"].isdisjoint(groups["test"])
