import numpy as np

from exercise import classify, fit_ridge, generalization_report, task_for_labels


def test_nominal_labels_select_classification() -> None:
    assert task_for_labels(["LOW", "HIGH", "LOW"]) == "classification"


def test_report_contains_holdout_and_baseline_evidence() -> None:
    assert generalization_report(train_score=1.0, holdout_score=0.8,
                                 baseline_score=0.6) == {
        "train_score": 1.0, "holdout_score": 0.8, "baseline_score": 0.6}


def test_threshold_is_an_explicit_decision_input() -> None:
    np.testing.assert_array_equal(
        classify(np.array([0.2, 0.55, 0.8]), threshold=0.7), [0, 0, 1])


def test_stronger_ridge_penalty_reduces_slope_magnitude() -> None:
    x = np.array([0.0, 1.0, 2.0, 3.0])
    y = np.array([1.0, 3.0, 5.0, 7.0])
    weak = fit_ridge(x, y, alpha=0.0)
    strong = fit_ridge(x, y, alpha=50.0)
    assert abs(strong[1]) < abs(weak[1])
