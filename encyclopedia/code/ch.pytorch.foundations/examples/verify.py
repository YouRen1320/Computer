import platform

import torch
from torch import nn
from torch.utils.data import DataLoader

from modeling import TicketDataset, TinyPriorityNet


FEATURES = torch.tensor(
    [[0.0, 0.0, 0.0], [1.0, 0.5, 0.0], [0.0, 1.0, 1.0], [1.0, 1.0, 1.0]],
    dtype=torch.float32,
)
LABELS = torch.tensor([0, 0, 1, 1], dtype=torch.int64)


def one_cpu_pass(seed: int) -> tuple[torch.Tensor, tuple[torch.Tensor, ...]]:
    torch.manual_seed(seed)
    dataset = TicketDataset(FEATURES, LABELS)
    assert len(dataset) == 4
    assert set(dataset[0]) == {"features", "label"}
    loader = DataLoader(dataset, batch_size=2, shuffle=False)
    batch = next(iter(loader))
    assert batch["features"].shape == (2, 3)
    assert batch["label"].shape == (2,)
    assert batch["features"].dtype == torch.float32
    assert batch["label"].dtype == torch.int64

    model = TinyPriorityNet().to("cpu")
    assert sum(parameter.numel() for parameter in model.parameters()) == 26
    model.zero_grad(set_to_none=True)
    logits = model(batch["features"])
    assert logits.shape == (2, 2)
    assert logits.device.type == "cpu"
    loss = nn.CrossEntropyLoss()(logits, batch["label"])
    assert loss.ndim == 0
    loss.backward()
    gradients = []
    for name, parameter in model.named_parameters():
        assert parameter.device.type == "cpu", name
        assert parameter.grad is not None, name
        assert parameter.grad.shape == parameter.shape, name
        assert torch.isfinite(parameter.grad).all(), name
        gradients.append(parameter.grad.detach().clone())
    return logits.detach().clone(), tuple(gradients)


first_logits, first_gradients = one_cpu_pass(20260724)
second_logits, second_gradients = one_cpu_pass(20260724)
torch.testing.assert_close(first_logits, second_logits, rtol=0, atol=0)
for first, second in zip(first_gradients, second_gradients, strict=True):
    torch.testing.assert_close(first, second, rtol=0, atol=0)

# Gradients accumulate unless explicitly cleared.
torch.manual_seed(7)
model = TinyPriorityNet().to("cpu")
criterion = nn.CrossEntropyLoss()
model.zero_grad(set_to_none=True)
criterion(model(FEATURES[:2]), LABELS[:2]).backward()
once = [p.grad.detach().clone() for p in model.parameters()]
criterion(model(FEATURES[:2]), LABELS[:2]).backward()
twice = [p.grad.detach().clone() for p in model.parameters()]
for one, two in zip(once, twice, strict=True):
    torch.testing.assert_close(two, 2 * one)
model.zero_grad(set_to_none=True)
assert all(parameter.grad is None for parameter in model.parameters())

print(
    f"PASS foundations CPU example: Python {platform.python_version()}, "
    f"PyTorch {torch.__version__}, device=cpu"
)
