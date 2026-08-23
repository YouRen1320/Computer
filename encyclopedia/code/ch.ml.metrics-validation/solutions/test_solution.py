import numpy as np
import pytest

from solution import classification_report, decision_report, group_holdout


def test_solution_contract() -> None:
    report = classification_report(np.array([1] * 5 + [0] * 95), np.zeros(100, dtype=int))
    assert report == {"accuracy": pytest.approx(0.95), "recall": 0.0, "precision": 0.0}
    groups = np.repeat(np.array(["A", "B", "C"]), 2)
    train, validation = group_holdout(groups, "B")
    assert set(groups[train]).isdisjoint(set(groups[validation]))
    assert decision_report([0.61, 0.95, 0.60], baseline="b", predeclared_gate="g") == {
        "score": pytest.approx(0.72), "baseline": "b", "predeclared_gate": "g"}
