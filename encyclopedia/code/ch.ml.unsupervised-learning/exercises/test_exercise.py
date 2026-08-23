import numpy as np

from exercise import interpretation_record, projection_report, same_partition, standardize


RAW = np.array([[1000.0, 0.01], [2000.0, 0.02], [1100.0, 0.90], [2100.0, 0.89]])


def test_distance_features_are_standardized() -> None:
    scaled = standardize(RAW)
    np.testing.assert_allclose(scaled.mean(axis=0), [0.0, 0.0], atol=1e-12)
    np.testing.assert_allclose(scaled.std(axis=0), [1.0, 1.0], atol=1e-12)


def test_stability_ignores_arbitrary_cluster_id_permutation() -> None:
    assert same_partition(np.array([0, 0, 1, 1]), np.array([1, 1, 0, 0]))
    assert not same_partition(np.array([0, 0, 1, 1]), np.array([0, 1, 0, 1]))


def test_projection_report_keeps_loss_and_explained_variance() -> None:
    report = projection_report(standardize(RAW))
    assert 0.0 < report["explained_variance_ratio"] < 1.0
    assert report["reconstruction_mse"] > 0.0


def test_interpretation_is_a_versioned_hypothesis_not_java_risk_fact() -> None:
    record = interpretation_record(seed_runs=5, data_version="devices-2026-07")
    assert record["seed_runs"] == 5 and record["data_version"] == "devices-2026-07"
    assert str(record["claim"]).startswith("待验证假设")
    assert "risk" not in str(record["claim"]).lower()
