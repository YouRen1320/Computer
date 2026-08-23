import unittest

from reliability import (audit_labels, availability_sli, burn_rate,
                         latency_sli, multi_window_alert, trace_findings)


class ReliabilityTest(unittest.TestCase):
    def test_low_cardinality_policy(self) -> None:
        self.assertEqual([], audit_labels({"service", "route", "status_class"}))
        self.assertEqual(["user_id"], audit_labels({"service", "user_id"}))

    def test_user_visible_slis(self) -> None:
        self.assertAlmostEqual(0.998, availability_sli(1000, 2).value)
        self.assertAlmostEqual(0.75, latency_sli([80, 110, 240, 700], 300))
        self.assertAlmostEqual(2.0, burn_rate(1000, 20, 0.99).value)

    def test_multi_window_alert_requires_both_windows(self) -> None:
        self.assertTrue(multi_window_alert(
            {"total": 100, "bad": 8}, {"total": 1000, "bad": 30}, 0.99,
            short_threshold=4, long_threshold=2).page)
        self.assertFalse(multi_window_alert(
            {"total": 100, "bad": 8}, {"total": 1000, "bad": 2}, 0.99,
            short_threshold=4, long_threshold=2).page)

    def test_no_traffic_and_missing_telemetry_are_explicit_states(self) -> None:
        self.assertEqual("zero-traffic", availability_sli(0, 0).state)
        self.assertEqual("zero-traffic", burn_rate(0, 0, 0.99).state)
        self.assertEqual("telemetry-missing", availability_sli(None, None).state)
        no_traffic = multi_window_alert(
            {"total": 0, "bad": 0}, {"total": 0, "bad": 0}, 0.99,
            short_threshold=4, long_threshold=2)
        self.assertEqual("pending-no-traffic", no_traffic.state)
        missing = multi_window_alert(
            {"total": None, "bad": None}, {"total": 10, "bad": 0}, 0.99,
            short_threshold=4, long_threshold=2)
        self.assertEqual("telemetry-alert", missing.state)

    def test_invalid_event_count_matrix_is_rejected(self) -> None:
        for total, bad in ((-1, 0), (1, -1), (2, 3)):
            with self.subTest(total=total, bad=bad):
                with self.assertRaises(ValueError):
                    burn_rate(total, bad, 0.99)

    def test_async_span_keeps_trace_and_parent(self) -> None:
        spans = [
            {"span_id": "root", "trace_id": "trace-a", "parent_span_id": None},
            {"span_id": "async", "trace_id": "trace-a", "parent_span_id": "root"},
        ]
        self.assertEqual([], trace_findings(spans))


if __name__ == "__main__":
    unittest.main()
