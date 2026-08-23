import torch
from torch import nn


def validation_forward(model: nn.Module, features: torch.Tensor) -> torch.Tensor:
    """TODO: switch behavior mode and disable graph recording for validation."""
    return model(features)  # Deliberate faults: still training and recording gradients.
