import unittest

from performance_gate import GOOD_RECORD, audit


class PerformanceGateFaultTest(unittest.TestCase):
    def test_good_record_passes(self) -> None:
        self.assertEqual([], audit(dict(GOOD_RECORD)))

    def test_no_warmup_and_client_saturation_are_invalid(self) -> None:
        errors = audit(dict(GOOD_RECORD, warmup_seconds=0, warmup_excluded=False, generator_cpu_max=92))
        self.assertTrue(any("warmup" in item for item in errors))
        self.assertTrue(any("generator" in item for item in errors))

    def test_average_only_and_production_data_are_invalid(self) -> None:
        record = dict(GOOD_RECORD, dataset_environment="production", dataset_isolated=False)
        del record["p95_ms"]
        del record["p99_ms"]
        errors = audit(record)
        self.assertTrue(any("p95" in item for item in errors))
        self.assertTrue(any("p99" in item for item in errors))
        self.assertTrue(any("production" in item for item in errors))

    def test_optimization_requires_same_inputs_and_functional_regression(self) -> None:
        errors = audit(
            dict(
                GOOD_RECORD,
                after_workload_id="easier-workload",
                after_dataset_id="smaller-data",
                functional_regression_passed=False,
            )
        )
        self.assertEqual(3, len(errors))


if __name__ == "__main__":
    unittest.main()
