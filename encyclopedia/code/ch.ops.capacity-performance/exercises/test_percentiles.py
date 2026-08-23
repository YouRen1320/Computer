import unittest

from percentiles import percentile


class PercentileExerciseTest(unittest.TestCase):
    def test_p50_and_p95_use_nearest_rank(self) -> None:
        values = [10] * 18 + [200, 900]
        self.assertEqual(10, percentile(values, 0.50))
        self.assertEqual(200, percentile(values, 0.95))

    def test_invalid_quantile_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            percentile([1, 2, 3], 0)


if __name__ == "__main__":
    unittest.main()
