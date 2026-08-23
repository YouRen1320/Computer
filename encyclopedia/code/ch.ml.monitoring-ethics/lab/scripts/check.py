"""Exercise distribution, label maturity, subgroup and governance boundaries."""

import json
import pathlib
import sys

import numpy as np
import pandas as pd


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from monitoring import backfill_labels, quality_report, synthetic_monitoring_report, validate_model_card


assert sys.version_info[:2] == (3, 14)
assert np.__version__ == "2.5.1"
assert pd.__version__ == "3.0.5"
card = json.loads((root / "model_card.json").read_text(encoding="utf-8"))
validate_model_card(card)

predictions = pd.DataFrame(
    {
        "prediction_id": [f"p{i}" for i in range(1, 9)],
        "group": ["A"] * 4 + ["B"] * 4,
        "prediction": [1, 0, 1, 0, 1, 1, 0, 0],
        "model_version": ["synthetic-1"] * 8,
    }
)
pending_records = predictions.assign(label=pd.array([pd.NA] * 8, dtype="Int64"))
pending = quality_report(pending_records)
assert pending["status"] == "pending_labels"
assert pending["label_coverage"] == 0.0
assert "accuracy" not in pending

labels = pd.DataFrame(
    {
        "prediction_id": [f"p{i}" for i in range(1, 9)],
        "label": [1, 0, 1, 0, 1, 0, 1, 0],
    }
)
mature = backfill_labels(predictions, labels)
report = synthetic_monitoring_report([0, 0, 2, 2], [1, 1, 1, 1], mature, card)
assert report["reference_mean"] == report["current_mean"] == 1.0
assert report["reference_bins"] == [0.5, 0.0, 0.5]
assert report["current_bins"] == [0.0, 1.0, 0.0]
assert report["input_tv"] == 1.0
assert report["input_drift_alert"] is True
assert report["input_claim"] == "distribution_signal_only_not_quality_proof"
quality = report["quality"]
assert quality["status"] == "available" and quality["accuracy"] == 0.75
assert quality["subgroups"]["A"] == {"count": 4, "accuracy": 1.0, "enough_evidence": True}
assert quality["subgroups"]["B"] == {"count": 4, "accuracy": 0.5, "enough_evidence": True}
assert quality["eligible_accuracy_gap"] == 0.5
assert report["subgroup_alert"] is True
assert "operator" in report["human_override"]

try:
    validate_model_card({"model_name": "incomplete"})
except ValueError as error:
    assert "missing" in str(error)
else:
    raise AssertionError("an incomplete model card must be rejected")

print("PASS: mean blind spot, TV signal, delayed labels, subgroup gap and model-card gate")
