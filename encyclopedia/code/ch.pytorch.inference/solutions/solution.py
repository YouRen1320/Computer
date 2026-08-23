import torch
from torch import nn


def predict_batch(model: nn.Module, features: torch.Tensor) -> torch.Tensor:
    if features.ndim != 2 or features.shape[1] != 3:
        raise ValueError("expected (batch, 3)")
    model.eval()
    with torch.inference_mode():
        return model(features)
