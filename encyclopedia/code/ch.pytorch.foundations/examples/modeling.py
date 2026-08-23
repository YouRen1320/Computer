from __future__ import annotations

import torch
from torch import Tensor, nn
from torch.utils.data import Dataset


class TicketDataset(Dataset[dict[str, Tensor]]):
    """Stable sample contract: float32 features and int64 scalar class label."""

    def __init__(self, features: Tensor, labels: Tensor) -> None:
        x = torch.as_tensor(features, dtype=torch.float32, device="cpu")
        y = torch.as_tensor(labels, dtype=torch.int64, device="cpu")
        if x.ndim != 2 or x.shape[1] != 3:
            raise ValueError("features must have shape (sample, 3)")
        if y.ndim != 1 or y.shape[0] != x.shape[0]:
            raise ValueError("labels must have shape (sample,)")
        if not torch.isfinite(x).all():
            raise ValueError("features must be finite")
        self.features = x
        self.labels = y

    def __len__(self) -> int:
        return self.features.shape[0]

    def __getitem__(self, index: int) -> dict[str, Tensor]:
        return {"features": self.features[index], "label": self.labels[index]}


class TinyPriorityNet(nn.Module):
    """Two-layer CPU teaching module; output is unnormalized two-class logits."""

    def __init__(self, input_features: int = 3, hidden_features: int = 4, classes: int = 2) -> None:
        super().__init__()
        self.hidden = nn.Linear(input_features, hidden_features)
        self.activation = nn.ReLU()
        self.output = nn.Linear(hidden_features, classes)

    def forward(self, features: Tensor) -> Tensor:
        parameter = next(self.parameters())
        if features.ndim != 2 or features.shape[1] != self.hidden.in_features:
            raise ValueError("features must have shape (batch, input_features)")
        if features.dtype != parameter.dtype:
            raise ValueError(f"dtype mismatch: input={features.dtype}, parameter={parameter.dtype}")
        if features.device != parameter.device:
            raise ValueError(f"device mismatch: input={features.device}, parameter={parameter.device}")
        hidden = self.activation(self.hidden(features))
        return self.output(hidden)
