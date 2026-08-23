import unittest

from percentiles import percentile


class PercentileSolutionTest(unittest.TestCase):
    def test_tail_is_visible(self) -> None:
        values = [10] * 18 + [200, 900]
        self.assertEqual(10, percentile(values, 0.50))
        self.assertEqual(200, percentile(values, 0.95))
        self.assertEqual(900, percentile(values, 0.99))

    def test_boundaries_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            percentile([], 0.95)
        with self.assertRaises(ValueError):
            percentile([1], 0)


if __name__ == "__main__":
    unittest.main()
