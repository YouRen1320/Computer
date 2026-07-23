import unittest

from reliability import (audit_labels, availability_sli, burn_rate,
                         latency_sli, multi_window_alert, trace_findings)


class ReliabilityTest(unittest.TestCase):
    def test_low_cardinality_policy(self) -> None:
        self.assertEqual([], audit_labels({"service", "route", "status_class"}))
        self.assertEqual(["user_id"], audit_labels({"service", "user_id"}))

    def test_user_visible_slis(self) -> None:
        self.assertAlmostEqual(0.998, availability_sli(1000, 2))
        self.assertAlmostEqual(0.75, latency_sli([80, 110, 240, 700], 300))
        self.assertAlmostEqual(2.0, burn_rate(1000, 20, 0.99))

    def test_multi_window_alert_requires_both_windows(self) -> None:
        self.assertTrue(multi_window_alert(
            {"total": 100, "bad": 8}, {"total": 1000, "bad": 30}, 0.99,
            short_threshold=4, long_threshold=2))
        self.assertFalse(multi_window_alert(
            {"total": 100, "bad": 8}, {"total": 1000, "bad": 2}, 0.99,
            short_threshold=4, long_threshold=2))

    def test_async_span_keeps_trace_and_parent(self) -> None:
        spans = [
            {"span_id": "root", "trace_id": "trace-a", "parent_span_id": None},
            {"span_id": "async", "trace_id": "trace-a", "parent_span_id": "root"},
        ]
        self.assertEqual([], trace_findings(spans))


if __name__ == "__main__":
    unittest.main()
