import torch
from torch import nn

from solution import predict_batch


model = nn.Sequential(nn.Dropout(0.5), nn.Linear(3, 2))
result = predict_batch(model, torch.ones((2, 3)))
assert not model.training and result.shape == (2, 2) and not result.requires_grad
try:
    predict_batch(model, torch.ones(3))
except ValueError:
    pass
else:
    raise AssertionError("invalid rank accepted")
print("PASS private inference solution on CPU")
