import numpy as np


def device_scores(features: np.ndarray, weights: np.ndarray, bias: np.ndarray) -> np.ndarray:
    """TODO: return a (batch, output) result and reject shape-contract violations."""
    # Deliberate fault: operands are reversed. Complete the contract before changing tests.
    return weights @ features + bias
