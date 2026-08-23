"""Verify a hand-computable drift signal and delayed-label semantics."""

import pathlib
import sys

import numpy as np


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from monitor import category_proportions, quality_snapshot, total_variation


assert sys.version_info[:2] == (3, 14)
assert np.__version__ == "2.5.1"
categories = ["pump", "motor"]
reference = category_proportions(["pump"] * 8 + ["motor"] * 2, categories)
current = category_proportions(["pump"] * 4 + ["motor"] * 6, categories)
np.testing.assert_allclose(reference, [0.8, 0.2])
np.testing.assert_allclose(current, [0.4, 0.6])
assert np.isclose(total_variation(reference, current), 0.4)

pending = quality_snapshot([1, 0, 1, 0], None, ["A", "A", "B", "B"])
assert pending == {"status": "pending_labels", "label_coverage": 0.0, "sample_count": 4}
assert "accuracy" not in pending

available = quality_snapshot(
    [1, 0, 1, 0, 1, 1, 0, 0],
    [1, 0, 1, 0, 1, 0, 1, 0],
    ["A", "A", "A", "A", "B", "B", "B", "B"],
)
assert available["accuracy"] == 0.75
assert available["subgroups"] == {
    "A": {"count": 4, "accuracy": 1.0},
    "B": {"count": 4, "accuracy": 0.5},
}
print("PASS: TV drift signal, pending-label state and subgroup quality")
