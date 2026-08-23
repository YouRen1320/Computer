import platform
import xml.etree.ElementTree as ET

import numpy as np

from repair_stats import (
    conditional_probability,
    describe_durations,
    discrete_moments,
    empirical_cdf,
    empirical_cdf_svg,
)


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

# This table is the exact plotting input for an empirical CDF: duplicate 20s
# contribute two observations, so the cumulative mass reaches 3/4 at x=20.
assert empirical_cdf([40, 10, 20, 20]) == [(10.0, 0.25), (20.0, 0.75), (40.0, 1.0)]
svg = ET.fromstring(empirical_cdf_svg([40, 10, 20, 20]))
namespace = {"svg": "http://www.w3.org/2000/svg"}
assert svg.attrib["role"] == "img"
assert svg.attrib["aria-labelledby"] == "cdf-title cdf-description"
assert len(svg.find("svg:polyline", namespace).attrib["points"].split()) == 8

# A discrete repair-count variable: E[X]=0*.2+1*.5+2*.3=1.1.
mean, variance = discrete_moments([0, 1, 2], [0.2, 0.5, 0.3])
np.testing.assert_allclose([mean, variance], [1.1, 0.49])

rng = np.random.default_rng(20260724)
frequency = float(rng.binomial(1, 0.3, size=20_000).mean())
assert abs(frequency - 0.3) <= 0.02

print(
    f"PASS probability example with empirical CDF table/SVG: Python {platform.python_version()}, "
    f"NumPy {np.__version__}, seeded frequency={frequency:.4f}"
)
