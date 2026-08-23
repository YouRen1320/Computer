import torch
from torch import nn


class TinyPriorityNet(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.hidden = nn.Linear(3, 4)
        self.output = nn.Linear(4, 1)  # Deliberate fault: contract requires two logits.

    def forward(self, features: torch.Tensor) -> torch.Tensor:
        return self.output(torch.relu(self.hidden(features)))
