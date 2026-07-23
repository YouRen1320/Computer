"""Intentionally incomplete drift detector that only compares means."""

from collections.abc import Sequence

import numpy as np


def input_drift_alert(reference: Sequence[float], current: Sequence[float]) -> bool:
    return bool(abs(float(np.mean(reference)) - float(np.mean(current))) >= 0.25)
