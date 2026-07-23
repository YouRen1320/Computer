"""Expected-red distribution-shape oracle."""

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from monitor import input_drift_alert


reference = [0.0, 0.0, 2.0, 2.0]
current = [1.0, 1.0, 1.0, 1.0]
assert input_drift_alert(reference, current), (
    "EXPECTED RED: equal means hide a complete fixed-bin distribution shift"
)
print("PASS: drift detector sees distribution changes beyond the mean")
