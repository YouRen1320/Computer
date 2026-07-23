from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
import random

import torch
from torch import Tensor, nn
from torch.utils.data import DataLoader, TensorDataset


@dataclass(frozen=True)
class TrainConfig:
    seed: int = 20260724
    epochs: int = 30
    batch_size: int = 4
    learning_rate: float = 0.1
    patience: int = 6


MODEL_CONFIG = {"input_features": 2, "hidden_features": 6, "classes": 2, "dropout": 0.2}


def seed_cpu(seed: int) -> None:
    random.seed(seed)
    torch.manual_seed(seed)


def build_model(config: dict = MODEL_CONFIG) -> nn.Module:
    return nn.Sequential(
        nn.Linear(config["input_features"], config["hidden_features"]),
        nn.ReLU(),
        nn.Dropout(config["dropout"]),
        nn.Linear(config["hidden_features"], config["classes"]),
    ).to("cpu")


def make_splits() -> tuple[TensorDataset, TensorDataset, TensorDataset]:
    # Artificial points only; labels are a teaching rule, not FactoryCare observations.
    train_x = torch.tensor(
        [[-2.0, -1.0], [-1.5, -0.5], [-1.0, -1.5], [-0.5, -1.0],
         [0.5, 1.0], [1.0, 1.5], [1.5, 0.5], [2.0, 1.0]], dtype=torch.float32
    )
    train_y = torch.tensor([0, 0, 0, 0, 1, 1, 1, 1], dtype=torch.int64)
    val_x = torch.tensor([[-1.25, -1.0], [-0.75, -0.5], [0.75, 0.5], [1.25, 1.0]])
    val_y = torch.tensor([0, 0, 1, 1], dtype=torch.int64)
    test_x = torch.tensor([[-1.75, -0.75], [-0.25, -0.5], [0.25, 0.5], [1.75, 0.75]])
    test_y = torch.tensor([0, 0, 1, 1], dtype=torch.int64)
    return TensorDataset(train_x, train_y), TensorDataset(val_x, val_y), TensorDataset(test_x, test_y)


def aggregate(logits: Tensor, labels: Tensor, loss: Tensor) -> tuple[float, int, int]:
    return float(loss.detach()) * labels.shape[0], int((logits.argmax(1) == labels).sum()), labels.shape[0]


def train_epoch(model: nn.Module, loader: DataLoader, optimizer: torch.optim.Optimizer) -> dict[str, float]:
    model.train()
    criterion = nn.CrossEntropyLoss()
    loss_sum = correct = count = 0
    for features, labels in loader:
        optimizer.zero_grad(set_to_none=True)
        logits = model(features)
        loss = criterion(logits, labels)
        loss.backward()
        assert all(p.grad is None or torch.isfinite(p.grad).all() for p in model.parameters())
        optimizer.step()
        batch_loss, batch_correct, batch_count = aggregate(logits, labels, loss)
        loss_sum += batch_loss
        correct += batch_correct
        count += batch_count
    return {"loss": loss_sum / count, "accuracy": correct / count}


def evaluate(model: nn.Module, loader: DataLoader) -> dict[str, float]:
    model.eval()
    criterion = nn.CrossEntropyLoss()
    loss_sum = correct = count = 0
    with torch.inference_mode():
        for features, labels in loader:
            logits = model(features)
            loss = criterion(logits, labels)
            batch_loss, batch_correct, batch_count = aggregate(logits, labels, loss)
            loss_sum += batch_loss
            correct += batch_correct
            count += batch_count
    return {"loss": loss_sum / count, "accuracy": correct / count}


class TestSetGate:
    def __init__(self, dataset: TensorDataset) -> None:
        self.dataset = dataset
        self.read_count = 0

    def loader_once(self) -> DataLoader:
        if self.read_count:
            raise RuntimeError("test set may only be read in the final evaluation")
        self.read_count += 1
        return DataLoader(self.dataset, batch_size=4, shuffle=False)


def validate_checkpoint(checkpoint: dict) -> None:
    required = {"schema_version", "model_config", "train_config", "model_state", "optimizer_state", "epoch", "best_val_loss"}
    missing = required - checkpoint.keys()
    if missing:
        raise ValueError(f"checkpoint missing keys: {sorted(missing)}")
    if checkpoint["schema_version"] != 1:
        raise ValueError("unsupported checkpoint schema")


def run_experiment(directory: Path, config: TrainConfig = TrainConfig()) -> dict:
    directory.mkdir(parents=True, exist_ok=True)
    seed_cpu(config.seed)
    train_data, val_data, test_data = make_splits()
    generator = torch.Generator(device="cpu").manual_seed(config.seed)
    train_loader = DataLoader(train_data, batch_size=config.batch_size, shuffle=True, generator=generator)
    val_loader = DataLoader(val_data, batch_size=4, shuffle=False)
    test_gate = TestSetGate(test_data)
    model = build_model()
    optimizer = torch.optim.SGD(model.parameters(), lr=config.learning_rate)
    checkpoint_path = directory / "best.pt"
    curves: list[dict] = []
    best_val_loss = float("inf")
    stale_epochs = 0

    for epoch in range(config.epochs):
        train_metrics = train_epoch(model, train_loader, optimizer)
        val_metrics = evaluate(model, val_loader)
        curves.append({"epoch": epoch, "train": train_metrics, "validation": val_metrics})
        if val_metrics["loss"] < best_val_loss:
            best_val_loss = val_metrics["loss"]
            stale_epochs = 0
            torch.save(
                {
                    "schema_version": 1,
                    "model_config": dict(MODEL_CONFIG),
                    "train_config": asdict(config),
                    "model_state": model.state_dict(),
                    "optimizer_state": optimizer.state_dict(),
                    "epoch": epoch,
                    "best_val_loss": best_val_loss,
                },
                checkpoint_path,
            )
        else:
            stale_epochs += 1
            if stale_epochs >= config.patience:
                break

    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=True)
    validate_checkpoint(checkpoint)
    restored = build_model(checkpoint["model_config"])
    restored.load_state_dict(checkpoint["model_state"])
    final_test = evaluate(restored, test_gate.loader_once())
    return {
        "checkpoint": checkpoint_path,
        "curves": curves,
        "best_epoch": checkpoint["epoch"],
        "best_val_loss": checkpoint["best_val_loss"],
        "test": final_test,
        "test_reads": test_gate.read_count,
        "restored_state": {name: value.detach().clone() for name, value in restored.state_dict().items()},
    }
