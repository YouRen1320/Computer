import json
import platform
from pathlib import Path
import subprocess
import sys
import tempfile
import time

import torch

from artifact import Predictor, export_artifact


ROWS = [
    {"age_hours": 10.0, "alerts_7d": 2.0, "days_since_service": 5.0},
    {"age_hours": 12.0, "alerts_7d": 3.0, "days_since_service": 10.0},
]

with tempfile.TemporaryDirectory() as parent:
    artifact_dir = export_artifact(Path(parent) / "artifact")
    predictor = Predictor(artifact_dir)
    batch = predictor.predict_batch(ROWS)
    torch.testing.assert_close(batch["logits"], torch.tensor([[0.1, -0.1], [-0.4, 3.4]]))
    assert batch["class_ids"].tolist() == [0, 1]
    assert batch["labels"] == ["normal", "review"]

    singles = [predictor.predict_one(row) for row in ROWS]
    for index, single in enumerate(singles):
        torch.testing.assert_close(single["logits"], batch["logits"][index], rtol=0, atol=0)
        assert single["class_id"] == int(batch["class_ids"][index])

    completed = subprocess.run(
        [sys.executable, str(Path(__file__).with_name("fresh_process.py")), str(artifact_dir)],
        check=True,
        capture_output=True,
        text=True,
    )
    fresh = json.loads(completed.stdout.strip().splitlines()[-1])
    assert fresh["model_version"] == "toy-1"
    torch.testing.assert_close(torch.tensor(fresh["logits"]), batch["logits"], rtol=0, atol=0)
    assert fresh["labels"] == batch["labels"]

    try:
        predictor.predict_one({"age_hours": 10.0, "alerts_7d": 2.0})
    except ValueError as exc:
        assert "keys differ" in str(exc)
    else:
        raise AssertionError("invalid input schema accepted")

    # Local CPU sanity measurement only: no threshold and no production latency claim.
    started = time.perf_counter()
    repeats = 100
    for _ in range(repeats):
        predictor.predict_batch(ROWS)
    elapsed = time.perf_counter() - started
    items_per_second = repeats * len(ROWS) / elapsed

print(
    f"PASS inference CPU example: Python {platform.python_version()}, PyTorch {torch.__version__}; "
    f"fresh_process=equal, local_sanity_ms={elapsed * 1000:.3f}, "
    f"local_items_per_second={items_per_second:.1f} (not a production benchmark)"
)
