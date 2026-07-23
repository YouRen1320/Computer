import numpy as np


durations = np.array([10.0, 20.0, 30.0, 40.0, 50.0])
assert durations.sum() == 150.0
assert durations.mean() == 30.0
assert np.sum((durations - 30.0) ** 2) == 1000.0
assert np.var(durations, ddof=0) == 200.0
assert np.var(durations, ddof=1) == 250.0

urgent = np.array([True, True, False, True, False, False, True, False])
late = np.array([True, False, True, True, False, False, False, True])
intersection = np.count_nonzero(urgent & late)
assert intersection == 2
assert intersection / np.count_nonzero(urgent) == 0.5  # P(late | urgent)
assert intersection / np.count_nonzero(late) == 0.5    # P(urgent | late), coincidentally equal here

# Use a second table to make direction visibly different.
condition_a = np.array([True, True, True, True, False, False])
event_b = np.array([True, False, False, False, True, False])
both = np.count_nonzero(condition_a & event_b)
assert both / np.count_nonzero(condition_a) == 0.25     # P(B | A)
assert both / np.count_nonzero(event_b) == 0.5          # P(A | B)

probabilities = np.array([0.2, 0.5, 0.3])
assert np.isclose(probabilities.sum(), 1.0)
try:
    bad = np.array([0.2, 0.5, 0.4])
    if not np.isclose(bad.sum(), 1.0):
        raise ValueError("probability mass sums to 1.1, not 1")
except ValueError as exc:
    assert "1.1" in str(exc)
else:
    raise AssertionError("invalid probability mass accepted")

# Sampling bias: selecting only the slowest three tickets changes the estimator.
population_mean = float(durations.mean())
biased_mean = float(durations[durations >= 30].mean())
assert population_mean == 30.0 and biased_mean == 40.0

# Correlation is only an association in this observational toy table.
staffing = np.array([1.0, 2.0, 3.0, 4.0])
repair_count = np.array([3.0, 5.0, 7.0, 9.0])
correlation = float(np.corrcoef(staffing, repair_count)[0, 1])
assert np.isclose(correlation, 1.0)
claim = "association only; no intervention or confounder control"
assert "no intervention" in claim

rng = np.random.default_rng(20260724)
frequency = float(rng.binomial(1, 0.3, 20_000).mean())
assert abs(frequency - 0.3) <= 0.02

print("PASS probability lab: denominator, ddof, sampling and causal-overclaim faults exposed")
