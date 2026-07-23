import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset


class UnstableDataset(Dataset):
    def __len__(self):
        return 2

    def __getitem__(self, index):
        sample = torch.tensor([float(index), 1.0])
        return {"features": sample} if index == 0 else (sample,)


# Fault 1: different return structures cannot be collated into one stable batch.
try:
    next(iter(DataLoader(UnstableDataset(), batch_size=2)))
except (TypeError, KeyError, RuntimeError):
    pass
else:
    raise AssertionError("unstable Dataset return structure was accepted")

# Fault 2: float64 data and float32 parameters fail at the forward operation.
layer = nn.Linear(2, 1).to("cpu")
try:
    layer(torch.ones((1, 2), dtype=torch.float64, device="cpu"))
except RuntimeError as exc:
    assert "dtype" in str(exc).lower() or "type" in str(exc).lower()
else:
    raise AssertionError("dtype mismatch unexpectedly succeeded")

# Device fault is contract-tested without pretending that an accelerator was exercised.
def require_device(value: torch.Tensor, expected: torch.device) -> None:
    if value.device != expected:
        raise ValueError(f"expected {expected}, got {value.device}")


try:
    require_device(torch.ones(1, device="cpu"), torch.device("meta"))
except ValueError as exc:
    assert "expected meta" in str(exc)
else:
    raise AssertionError("declared device mismatch was accepted")

# Fault 3: modifying a leaf requiring gradients in place is rejected.
leaf = torch.tensor([2.0], requires_grad=True)
try:
    leaf.add_(1.0)
except RuntimeError as exc:
    assert "leaf" in str(exc).lower() or "grad" in str(exc).lower()
else:
    raise AssertionError("unsafe in-place leaf mutation unexpectedly succeeded")

# Fault 4: backward accumulates, then zero_grad(set_to_none=True) repairs state.
torch.manual_seed(9)
model = nn.Linear(2, 1)
x = torch.tensor([[1.0, 2.0]])
y = torch.tensor([[0.0]])
loss = (model(x) - y).square().mean()
loss.backward()
first = [p.grad.detach().clone() for p in model.parameters()]
(model(x) - y).square().mean().backward()
second = [p.grad.detach().clone() for p in model.parameters()]
for one, two in zip(first, second, strict=True):
    torch.testing.assert_close(two, 2 * one)
model.zero_grad(set_to_none=True)
assert all(p.grad is None for p in model.parameters())

print("PASS foundations lab: structure, dtype, declared device, in-place and accumulation faults exposed")
