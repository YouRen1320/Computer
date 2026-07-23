import torch

from starter import TinyPriorityNet


torch.manual_seed(20260724)
model = TinyPriorityNet().to("cpu")
features = torch.tensor([[0.0, 1.0, 2.0], [1.0, 0.0, 1.0]], dtype=torch.float32)
logits = model(features)
assert logits.shape == (2, 2), f"expected two class logits, got {tuple(logits.shape)}"
loss = torch.nn.CrossEntropyLoss()(logits, torch.tensor([0, 1]))
model.zero_grad(set_to_none=True)
loss.backward()
assert all(p.grad is not None and torch.isfinite(p.grad).all() for p in model.parameters())
