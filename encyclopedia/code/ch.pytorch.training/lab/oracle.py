import tempfile
from pathlib import Path

import torch
from torch import nn


# Fault 1: train mode keeps Dropout active; eval mode is stable for identical input.
torch.manual_seed(20260724)
model = nn.Sequential(nn.Dropout(p=0.5), nn.Linear(64, 2)).to("cpu")
x = torch.ones((4, 64))
model.train()
train_a = model(x)
train_b = model(x)
assert model.training and not torch.equal(train_a, train_b)
model.eval()
with torch.inference_mode():
    eval_a = model(x)
    eval_b = model(x)
assert not model.training
torch.testing.assert_close(eval_a, eval_b, rtol=0, atol=0)

# Fault 2: eval() alone does not disable gradients; a bad validation backward populates them.
model.zero_grad(set_to_none=True)
bad_loss = model(x).square().mean()
assert bad_loss.requires_grad
bad_loss.backward()
assert any(p.grad is not None for p in model.parameters())
model.zero_grad(set_to_none=True)
with torch.inference_mode():
    repaired = model(x).square().mean()
assert not repaired.requires_grad
assert all(p.grad is None for p in model.parameters())

# Fault 3: a gate makes test-set reuse observable rather than relying on convention.
class Gate:
    def __init__(self):
        self.reads = 0

    def read(self):
        if self.reads:
            raise RuntimeError("test set already consumed")
        self.reads += 1
        return ["final-only"]


gate = Gate()
assert gate.read() == ["final-only"]
try:
    gate.read()
except RuntimeError as exc:
    assert "already consumed" in str(exc)
else:
    raise AssertionError("test-set reuse was accepted")

# Fault 4: weights without construction/training metadata are not a resumable checkpoint.
def validate_checkpoint(checkpoint):
    required = {"schema_version", "model_config", "train_config", "model_state", "optimizer_state", "epoch"}
    missing = required - checkpoint.keys()
    if missing:
        raise ValueError(f"missing {sorted(missing)}")


with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "bad.pt"
    torch.save({"model_state": model.state_dict()}, path)
    incomplete = torch.load(path, map_location="cpu", weights_only=True)
    try:
        validate_checkpoint(incomplete)
    except ValueError as exc:
        assert "model_config" in str(exc)
    else:
        raise AssertionError("incomplete checkpoint was accepted")

print("PASS training lab: mode, validation-grad, test reuse and incomplete checkpoint faults exposed")
