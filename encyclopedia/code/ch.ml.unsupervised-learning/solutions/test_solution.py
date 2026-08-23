import numpy as np

from solution import interpretation_record, projection_report, same_partition, standardize


def test_solution_contract() -> None:
    raw = np.array([[1000.0, 0.01], [2000.0, 0.02], [1100.0, 0.90], [2100.0, 0.89]])
    scaled = standardize(raw)
    np.testing.assert_allclose(scaled.std(axis=0), [1, 1])
    assert same_partition(np.array([0, 0, 1, 1]), np.array([1, 1, 0, 0]))
    report = projection_report(scaled)
    assert 0 < report["explained_variance_ratio"] < 1 and report["reconstruction_mse"] > 0
    assert str(interpretation_record(seed_runs=5, data_version="v1")["claim"]).startswith("待验证假设")
