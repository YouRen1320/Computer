from pathlib import Path
import tempfile

import torch
from torch import nn


REQUIRED = {"weights.pt", "model.json", "preprocessing.json", "labels.json", "manifest.json"}


def require_bundle(directory: Path) -> None:
    present = {path.name for path in directory.iterdir()}
    missing = REQUIRED - present
    if missing:
        raise ValueError(f"missing {sorted(missing)}")


# Fault 1: weights alone do not reconstruct architecture, preprocessing or labels.
with tempfile.TemporaryDirectory() as parent:
    directory = Path(parent)
    torch.save(nn.Linear(3, 2).state_dict(), directory / "weights.pt")
    try:
        require_bundle(directory)
    except ValueError as exc:
        assert "model.json" in str(exc) and "preprocessing.json" in str(exc)
    else:
        raise AssertionError("weights-only artifact accepted")

# Fault 2: preprocessing drift changes the exact same model input and prediction.
raw = torch.tensor([[12.0, 3.0, 10.0]])
correct = (raw - torch.tensor([10.0, 2.0, 5.0])) / torch.tensor([2.0, 1.0, 5.0])
drifted = (raw - torch.tensor([0.0, 0.0, 0.0])) / torch.tensor([1.0, 1.0, 1.0])
assert not torch.equal(correct, drifted)
fixed = nn.Linear(3, 2, bias=False)
with torch.no_grad():
    fixed.weight.copy_(torch.tensor([[1.0, 0.0, 0.0], [0.0, 1.0, 1.0]]))
assert not torch.equal(fixed(correct), fixed(drifted))

# Fault 3: eval() changes module behavior but does not disable gradient recording.
fixed.eval()
bad_output = fixed(correct)
assert bad_output.requires_grad
with torch.inference_mode():
    repaired_output = fixed(correct)
assert not repaired_output.requires_grad

# Fault 4: rank/width checks reject ambiguous batch shapes before the model call.
def require_batch(value: torch.Tensor) -> None:
    if value.ndim != 2 or value.shape[1] != 3:
        raise ValueError(f"expected (batch, 3), got {tuple(value.shape)}")


for invalid in (torch.ones(3), torch.ones((2, 2)), torch.ones((1, 3, 1))):
    try:
        require_batch(invalid)
    except ValueError:
        continue
    raise AssertionError(f"invalid batch accepted: {tuple(invalid.shape)}")

print("PASS inference lab: incomplete bundle, preprocessing drift, graph and shape faults exposed")
