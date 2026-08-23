import torch

from solution import TinyPriorityNet


torch.manual_seed(20260724)
model = TinyPriorityNet().to("cpu")
x = torch.tensor([[0.0, 1.0, 2.0], [1.0, 0.0, 1.0]])
logits = model(x)
assert logits.shape == (2, 2)
loss = torch.nn.CrossEntropyLoss()(logits, torch.tensor([0, 1]))
model.zero_grad(set_to_none=True)
loss.backward()
assert all(p.grad is not None and torch.isfinite(p.grad).all() for p in model.parameters())
print("PASS private foundations solution on CPU")
