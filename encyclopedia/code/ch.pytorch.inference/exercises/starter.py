import torch
from torch import nn


def predict_batch(model: nn.Module, features: torch.Tensor) -> torch.Tensor:
    """TODO: validate shape, enter evaluation behavior, and disable graph recording."""
    return model(features)  # Deliberate fault: training behavior and autograd remain active.
