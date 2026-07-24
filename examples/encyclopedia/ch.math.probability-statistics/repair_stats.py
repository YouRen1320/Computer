from __future__ import annotations

from collections.abc import Sequence

import numpy as np


def describe_durations(values: Sequence[float]) -> dict[str, float]:
    durations = np.asarray(values, dtype=np.float64)
    if durations.ndim != 1 or durations.size == 0:
        raise ValueError("durations must be a non-empty 1-D sample")
    if not np.isfinite(durations).all() or (durations < 0).any():
        raise ValueError("durations must be finite and non-negative")
    return {
        "mean": float(np.mean(durations)),
        "median": float(np.median(durations)),
        "q25": float(np.quantile(durations, 0.25)),
        "q75": float(np.quantile(durations, 0.75)),
        "population_variance": float(np.var(durations, ddof=0)),
        "sample_variance": float(np.var(durations, ddof=1)) if durations.size > 1 else float("nan"),
    }


def conditional_probability(event: Sequence[bool], condition: Sequence[bool]) -> float:
    event_array = np.asarray(event, dtype=bool)
    condition_array = np.asarray(condition, dtype=bool)
    if event_array.shape != condition_array.shape or event_array.ndim != 1:
        raise ValueError("event and condition must be equal-length 1-D arrays")
    denominator = int(np.count_nonzero(condition_array))
    if denominator == 0:
        raise ValueError("conditional probability is undefined for an empty condition")
    numerator = int(np.count_nonzero(event_array & condition_array))
    return numerator / denominator


def empirical_cdf(values: Sequence[float]) -> list[tuple[float, float]]:
    """Return sorted support points and cumulative empirical probabilities."""
    sample = np.asarray(values, dtype=np.float64)
    if sample.ndim != 1 or sample.size == 0:
        raise ValueError("values must be a non-empty 1-D sample")
    if not np.isfinite(sample).all():
        raise ValueError("values must be finite")
    support, counts = np.unique(sample, return_counts=True)
    cumulative = np.cumsum(counts) / sample.size
    return [(float(value), float(probability)) for value, probability in zip(support, cumulative, strict=True)]


def empirical_cdf_svg(values: Sequence[float], *, width: int = 320, height: int = 200) -> str:
    """Draw an accessible, dependency-free SVG step plot for an empirical CDF."""
    if width < 120 or height < 120:
        raise ValueError("plot dimensions must be at least 120 by 120")
    cdf = empirical_cdf(values)
    margin = 30
    x_min, x_max = cdf[0][0], cdf[-1][0]
    x_span = x_max - x_min or 1.0

    def x_pixel(value: float) -> float:
        return margin + (value - x_min) / x_span * (width - 2 * margin)

    def y_pixel(probability: float) -> float:
        return height - margin - probability * (height - 2 * margin)

    points = [(x_pixel(x_min), y_pixel(0.0))]
    previous = 0.0
    for value, probability in cdf:
        points.extend([(x_pixel(value), y_pixel(previous)), (x_pixel(value), y_pixel(probability))])
        previous = probability
    points.append((x_pixel(x_max), y_pixel(previous)))
    coordinates = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        'role="img" aria-labelledby="cdf-title cdf-description">'
        '<title id="cdf-title">Empirical cumulative distribution</title>'
        '<desc id="cdf-description">Step plot of observed values and cumulative sample proportions.</desc>'
        f'<line x1="{margin}" y1="{height - margin}" x2="{width - margin}" y2="{height - margin}" stroke="black"/>'
        f'<line x1="{margin}" y1="{margin}" x2="{margin}" y2="{height - margin}" stroke="black"/>'
        f'<polyline fill="none" stroke="blue" points="{coordinates}"/>'
        '</svg>'
    )


def discrete_moments(values: Sequence[float], probabilities: Sequence[float]) -> tuple[float, float]:
    x = np.asarray(values, dtype=np.float64)
    p = np.asarray(probabilities, dtype=np.float64)
    if x.ndim != 1 or x.shape != p.shape or x.size == 0:
        raise ValueError("values and probabilities must be matching non-empty vectors")
    if (p < 0).any() or not np.isclose(p.sum(), 1.0):
        raise ValueError("probabilities must be non-negative and sum to one")
    expectation = float(np.sum(x * p))
    variance = float(np.sum((x - expectation) ** 2 * p))
    return expectation, variance
