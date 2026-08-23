import torch
from torch import nn


class TinyPriorityNet(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.hidden = nn.Linear(3, 4)
        self.output = nn.Linear(4, 2)

    def forward(self, features: torch.Tensor) -> torch.Tensor:
        if features.ndim != 2 or features.shape[1] != 3:
            raise ValueError("expected (batch, 3)")
        return self.output(torch.relu(self.hidden(features)))
