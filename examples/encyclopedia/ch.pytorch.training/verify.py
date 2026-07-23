from pathlib import Path
import platform
import tempfile

import torch

from training import run_experiment


with tempfile.TemporaryDirectory() as first_dir, tempfile.TemporaryDirectory() as second_dir:
    first = run_experiment(Path(first_dir))
    second = run_experiment(Path(second_dir))
    assert first["test_reads"] == second["test_reads"] == 1
    assert first["best_epoch"] == second["best_epoch"]
    torch.testing.assert_close(torch.tensor(first["best_val_loss"]), torch.tensor(second["best_val_loss"]), rtol=0, atol=0)
    assert len(first["curves"]) == len(second["curves"])
    for name in first["restored_state"]:
        torch.testing.assert_close(first["restored_state"][name], second["restored_state"][name], rtol=0, atol=0)
    assert first["checkpoint"].is_file()
    assert first["curves"][0]["train"]["loss"] > first["curves"][-1]["train"]["loss"]

print(
    f"PASS training CPU example: Python {platform.python_version()}, PyTorch {torch.__version__}; "
    f"same-seed state exact, test_reads=1, epochs={len(first['curves'])}"
)
