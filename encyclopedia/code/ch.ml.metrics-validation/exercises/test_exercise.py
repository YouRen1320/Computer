import numpy as np
import pytest

from exercise import classification_report, decision_report, group_holdout


def test_minority_metric_is_not_hidden_by_accuracy() -> None:
    actual = np.array([1] * 5 + [0] * 95)
    predicted = np.zeros(100, dtype=int)
    report = classification_report(actual, predicted)
    assert report["accuracy"] == pytest.approx(0.95)
    assert report["recall"] == pytest.approx(0.0)
    assert report["precision"] == pytest.approx(0.0)


def test_group_holdout_has_no_entity_leakage() -> None:
    groups = np.repeat(np.array(["A", "B", "C"]), 2)
    train, validation = group_holdout(groups, "B")
    assert set(groups[train]).isdisjoint(set(groups[validation]))
    assert set(groups[validation]) == {"B"}


def test_report_uses_all_folds_and_keeps_decision_contract() -> None:
    report = decision_report([0.61, 0.95, 0.60], baseline="predict-no-positive",
                             predeclared_gate="recall>=0.9")
    assert report == {
        "score": pytest.approx((0.61 + 0.95 + 0.60) / 3),
        "baseline": "predict-no-positive",
        "predeclared_gate": "recall>=0.9",
    }
