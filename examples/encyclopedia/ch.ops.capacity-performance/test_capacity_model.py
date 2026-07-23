import unittest

from capacity_model import compare_before_after, fixture_run, infer_bottleneck, percentile, summarize


class CapacityModelTest(unittest.TestCase):
    def test_percentiles_expose_tail_hidden_by_average(self) -> None:
        values = [20] * 18 + [200, 900]
        self.assertEqual(20, percentile(values, 0.50))
        self.assertEqual(200, percentile(values, 0.95))
        self.assertEqual(900, percentile(values, 0.99))

    def test_littles_law_and_peak_projection_are_explicit_assumptions(self) -> None:
        run = fixture_run([100] * 20, [5] * 20, plan="plan-before")
        self.assertEqual(5, run.workload.expected_concurrency())
        self.assertEqual(75, run.workload.projected_peak_rate())

    def test_fixed_workload_supports_before_after_claim(self) -> None:
        before = fixture_run([90] * 18 + [420, 650], [45] * 20, plan="plan-seq-scan")
        after = fixture_run([70] * 18 + [130, 180], [8] * 20, plan="plan-index-scan")
        self.assertEqual("database-wait-path", infer_bottleneck(before))
        comparison = compare_before_after(before, after)
        self.assertEqual(420, comparison["p95_before_ms"])
        self.assertEqual(130, comparison["p95_after_ms"])
        self.assertEqual(0, summarize(after)["error_rate"])


if __name__ == "__main__":
    unittest.main()
