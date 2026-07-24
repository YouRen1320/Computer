import pandas as pd


FORBIDDEN_FEATURES = {"closed_at", "final_status", "resolution_note"}
PROBLEM_CARD = {
    "business_decision": "prioritize work orders for dispatcher review",
    "sample_unit": "one work-order snapshot at cutoff_at",
    "prediction_time": "cutoff_at",
    "target": "work order breaches its response objective",
    "target_horizon": "within 24 hours after cutoff_at",
    "baseline": "predict no breach for every work order",
    "false_positive_cost": "dispatcher reviews a low-risk order",
    "false_negative_cost": "a high-risk order is not escalated in time",
    "preprocessing_fit_scope": "train-only-after-split",
}
REQUIRED_PROBLEM_FIELDS = frozenset(PROBLEM_CARD)


def assert_problem_card(card: dict[str, str]) -> None:
    missing = REQUIRED_PROBLEM_FIELDS - card.keys()
    assert not missing, f"problem card missing: {sorted(missing)}"
    assert all(isinstance(card[name], str) and card[name].strip() for name in REQUIRED_PROBLEM_FIELDS)
    assert card["preprocessing_fit_scope"] == "train-only-after-split"


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


def assert_manifest(manifest: pd.DataFrame, feature_names: set[str]) -> None:
    leaked_features = FORBIDDEN_FEATURES & feature_names
    assert not leaked_features, f"post-outcome features leak the target: {sorted(leaked_features)}"
    assert manifest["sample_id"].is_unique
    assert not manifest["split"].isna().any()
    assert (manifest["label_ready_at"] >= manifest["cutoff_at"]).all()
    groups = {name: set(part["entity_id"]) for name, part in manifest.groupby("split", observed=True)}
    assert groups["train"].isdisjoint(groups["validation"])
    assert groups["train"].isdisjoint(groups["test"])
    assert groups["validation"].isdisjoint(groups["test"])
    boundaries = {
        name: (part["cutoff_at"].min(), part["cutoff_at"].max())
        for name, part in manifest.groupby("split", observed=True)
    }
    assert boundaries["train"][1] < boundaries["validation"][0] < boundaries["test"][0]
