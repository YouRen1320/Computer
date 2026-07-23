import torch
from torch import nn

from solution import validation_forward


model = nn.Sequential(nn.Dropout(0.5), nn.Linear(8, 2))
output = validation_forward(model, torch.ones((3, 8)))
assert not model.training and not output.requires_grad
print("PASS private training solution on CPU")
