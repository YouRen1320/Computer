import numpy as np

from solution import classify, fit_ridge, generalization_report, task_for_labels


def test_solution_contract() -> None:
    assert task_for_labels(["LOW", "HIGH"]) == "classification"
    assert generalization_report(train_score=1.0, holdout_score=0.8, baseline_score=0.6)["holdout_score"] == 0.8
    np.testing.assert_array_equal(classify(np.array([0.55, 0.8]), threshold=0.7), [0, 1])
    x = np.array([0.0, 1.0, 2.0, 3.0]); y = np.array([1.0, 3.0, 5.0, 7.0])
    assert abs(fit_ridge(x, y, 50.0)[1]) < abs(fit_ridge(x, y, 0.0)[1])
