"""Verify fixed-bin proportions and carefully scoped drift wording."""

import pathlib
import sys

import numpy as np


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from monitor import input_drift_alert, input_drift_distance, proportions


reference = [0.0, 0.0, 2.0, 2.0]
current = [1.0, 1.0, 1.0, 1.0]
np.testing.assert_allclose(proportions(reference), [0.5, 0.0, 0.5])
np.testing.assert_allclose(proportions(current), [0.0, 1.0, 0.0])
assert input_drift_distance(reference, current) == 1.0
assert input_drift_alert(reference, current)
print("PASS: fixed-bin input-distribution signal detected; no quality claim was made")
