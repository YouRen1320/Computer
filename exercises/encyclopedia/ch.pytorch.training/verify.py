import torch
from torch import nn

from starter import validation_forward


torch.manual_seed(1)
model = nn.Sequential(nn.Dropout(0.5), nn.Linear(8, 2))
output = validation_forward(model, torch.ones((3, 8)))
assert model.training is False, "validation must call eval()"
assert output.requires_grad is False, "validation must not record an autograd graph"
