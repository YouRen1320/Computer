import torch
from torch import nn


def validation_forward(model: nn.Module, features: torch.Tensor) -> torch.Tensor:
    model.eval()
    with torch.inference_mode():
        return model(features)
