import platform

import numpy as np

from repair_stats import conditional_probability, describe_durations, discrete_moments


# Hand oracle for [10,20,30,40,50]: mean=150/5=30;
# squared deviations sum to 1000, so population variance=200 and sample variance=250.
stats = describe_durations([10, 20, 30, 40, 50])
expected = {
    "mean": 30.0,
    "median": 30.0,
    "q25": 20.0,
    "q75": 40.0,
    "population_variance": 200.0,
    "sample_variance": 250.0,
}
assert stats == expected

urgent = [True, True, False, True, False, False, True, False]
late = [True, False, True, True, False, False, False, True]
# Four urgent tickets, two of which are late: P(late | urgent)=2/4=0.5.
assert conditional_probability(late, urgent) == 0.5

# A discrete repair-count variable: E[X]=0*.2+1*.5+2*.3=1.1.
mean, variance = discrete_moments([0, 1, 2], [0.2, 0.5, 0.3])
np.testing.assert_allclose([mean, variance], [1.1, 0.49])

rng = np.random.default_rng(20260724)
frequency = float(rng.binomial(1, 0.3, size=20_000).mean())
assert abs(frequency - 0.3) <= 0.02

print(
    f"PASS probability example: Python {platform.python_version()}, "
    f"NumPy {np.__version__}, seeded frequency={frequency:.4f}"
)
