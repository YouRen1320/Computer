import json
from pathlib import Path
import sys

from artifact import Predictor


rows = [
    {"age_hours": 10.0, "alerts_7d": 2.0, "days_since_service": 5.0},
    {"age_hours": 12.0, "alerts_7d": 3.0, "days_since_service": 10.0},
]
result = Predictor(Path(sys.argv[1])).predict_batch(rows)
print(json.dumps({
    "model_version": result["model_version"],
    "logits": result["logits"].tolist(),
    "class_ids": result["class_ids"].tolist(),
    "labels": result["labels"],
}, sort_keys=True))
