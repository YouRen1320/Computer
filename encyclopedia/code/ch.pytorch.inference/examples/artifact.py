from __future__ import annotations

from hashlib import sha256
import json
import math
from pathlib import Path
from typing import Any

import torch
from torch import Tensor, nn


MODEL_CONFIG = {"input_features": 3, "hidden_features": 4, "classes": 2, "dropout": 0.25}
PREPROCESSING = {
    "feature_order": ["age_hours", "alerts_7d", "days_since_service"],
    "mean": [10.0, 2.0, 5.0],
    "scale": [2.0, 1.0, 5.0],
    "dtype": "float32",
}
LABELS = {"0": "normal", "1": "review"}


def build_model(config: dict[str, Any]) -> nn.Module:
    if config != MODEL_CONFIG:
        raise ValueError("unsupported model configuration")
    return nn.Sequential(
        nn.Linear(3, 4),
        nn.ReLU(),
        nn.Dropout(config["dropout"]),
        nn.Linear(4, 2),
    ).to("cpu")


def install_known_weights(model: nn.Module) -> None:
    first: nn.Linear = model[0]
    output: nn.Linear = model[3]
    with torch.no_grad():
        first.weight.copy_(torch.tensor([[1., 0., 0.], [0., 1., 0.], [0., 0., 1.], [1., 1., 1.]]))
        first.bias.zero_()
        output.weight.copy_(torch.tensor([[1., 0., 0., -0.5], [0., 1., 1., 0.5]]))
        output.bias.copy_(torch.tensor([0.1, -0.1]))


def file_digest(path: Path) -> str:
    digest = sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(65536), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def export_artifact(directory: Path) -> Path:
    directory.mkdir(parents=True, exist_ok=False)
    torch.manual_seed(20260724)
    model = build_model(MODEL_CONFIG)
    install_known_weights(model)
    torch.save(model.state_dict(), directory / "weights.pt")
    write_json(directory / "model.json", {"schema_version": 1, **MODEL_CONFIG})
    write_json(directory / "preprocessing.json", {"schema_version": 1, **PREPROCESSING})
    write_json(directory / "labels.json", {"schema_version": 1, "labels": LABELS})
    files = ["weights.pt", "model.json", "preprocessing.json", "labels.json"]
    write_json(
        directory / "manifest.json",
        {
            "artifact_schema": 1,
            "model_id": "factorycare-toy-priority",
            "model_version": "toy-1",
            "framework": "pytorch",
            "files": {name: file_digest(directory / name) for name in files},
        },
    )
    return directory


def load_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path.name} must contain an object")
    return value


def validate_artifact(directory: Path) -> dict:
    required = {"manifest.json", "weights.pt", "model.json", "preprocessing.json", "labels.json"}
    present = {path.name for path in directory.iterdir() if path.is_file()}
    missing = required - present
    if missing:
        raise ValueError(f"artifact missing files: {sorted(missing)}")
    manifest = load_json(directory / "manifest.json")
    if manifest.get("artifact_schema") != 1:
        raise ValueError("unsupported artifact schema")
    hashes = manifest.get("files")
    if not isinstance(hashes, dict):
        raise ValueError("manifest files must be a hash mapping")
    for name in required - {"manifest.json"}:
        if hashes.get(name) != file_digest(directory / name):
            raise ValueError(f"integrity check failed for {name}")
    return manifest


def preprocess(rows: list[dict[str, Any]], contract: dict) -> Tensor:
    if not rows:
        raise ValueError("at least one row is required")
    order = contract.get("feature_order")
    mean = contract.get("mean")
    scale = contract.get("scale")
    if order != PREPROCESSING["feature_order"] or len(mean) != 3 or len(scale) != 3:
        raise ValueError("unsupported preprocessing contract")
    values = []
    expected_keys = set(order)
    for index, row in enumerate(rows):
        if set(row) != expected_keys:
            raise ValueError(f"row {index} keys differ from input schema")
        vector = []
        for key in order:
            value = row[key]
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
                raise ValueError(f"row {index} field {key} must be a finite number")
            vector.append(float(value))
        values.append(vector)
    tensor = torch.tensor(values, dtype=torch.float32, device="cpu")
    mean_tensor = torch.tensor(mean, dtype=torch.float32)
    scale_tensor = torch.tensor(scale, dtype=torch.float32)
    if (scale_tensor <= 0).any():
        raise ValueError("preprocessing scales must be positive")
    return (tensor - mean_tensor) / scale_tensor


class Predictor:
    def __init__(self, directory: Path) -> None:
        self.manifest = validate_artifact(directory)
        model_doc = load_json(directory / "model.json")
        preprocessing_doc = load_json(directory / "preprocessing.json")
        labels_doc = load_json(directory / "labels.json")
        if model_doc.pop("schema_version", None) != 1 or preprocessing_doc.pop("schema_version", None) != 1:
            raise ValueError("unsupported component schema")
        if labels_doc.get("schema_version") != 1 or labels_doc.get("labels") != LABELS:
            raise ValueError("unsupported label mapping")
        self.preprocessing = preprocessing_doc
        self.labels = labels_doc["labels"]
        self.model = build_model(model_doc)
        state = torch.load(directory / "weights.pt", map_location="cpu", weights_only=True)
        self.model.load_state_dict(state, strict=True)
        self.model.eval()

    def predict_batch(self, rows: list[dict[str, Any]]) -> dict[str, Any]:
        features = preprocess(rows, self.preprocessing)
        with torch.inference_mode():
            logits = self.model(features)
            class_ids = logits.argmax(dim=1)
        assert logits.shape == (len(rows), 2)
        assert not logits.requires_grad
        return {
            "model_version": self.manifest["model_version"],
            "logits": logits.cpu(),
            "class_ids": class_ids.cpu(),
            "labels": [self.labels[str(int(value))] for value in class_ids],
        }

    def predict_one(self, row: dict[str, Any]) -> dict[str, Any]:
        batch = self.predict_batch([row])
        return {
            "model_version": batch["model_version"],
            "logits": batch["logits"][0],
            "class_id": int(batch["class_ids"][0]),
            "label": batch["labels"][0],
        }
