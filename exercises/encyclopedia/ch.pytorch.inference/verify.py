import torch
from torch import nn

from starter import predict_batch


model = nn.Sequential(nn.Dropout(0.5), nn.Linear(3, 2))
result = predict_batch(model, torch.ones((2, 3)))
assert model.training is False
assert result.shape == (2, 2)
assert result.requires_grad is False
try:
    predict_batch(model, torch.ones(3))
except ValueError:
    pass
else:
    raise AssertionError("rank-one input must be rejected")
