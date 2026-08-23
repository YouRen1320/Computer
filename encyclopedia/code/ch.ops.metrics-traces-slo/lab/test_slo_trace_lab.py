import copy
import unittest
from pathlib import Path

from slo_trace_lab import evaluate, load_fixture


class SloTraceLabTest(unittest.TestCase):
    def setUp(self) -> None:
        self.data = load_fixture(Path(__file__).with_name("reliability-fixture.json"))

    def test_fault_changes_slis_pages_and_points_to_leaf_causes(self) -> None:
        result = evaluate(self.data)
        self.assertTrue(result["verified"])
        self.assertGreater(result["burn_rate"]["fault_short"], result["burn_rate"]["normal_short"])
        self.assertEqual(["postgresql.query", "inventory.http"],
                         [item["cause"] for item in result["trace_results"]])

    def test_high_cardinality_label_is_rejected(self) -> None:
        altered = copy.deepcopy(self.data)
        altered["metric_contract"][0]["labels"].append("user_id")
        result = evaluate(altered)
        self.assertFalse(result["checks"]["low_cardinality_labels"])
        self.assertIn("factorycare_http_requests_total:user_id", result["label_findings"])

    def test_async_context_break_is_detected(self) -> None:
        altered = copy.deepcopy(self.data)
        altered["traces"][0]["spans"][2]["trace_id"] = "cccccccccccccccccccccccccccccccc"
        self.assertFalse(evaluate(altered)["checks"]["trace_continuity"])

    def test_one_hot_window_does_not_page_when_long_window_is_normal(self) -> None:
        altered = copy.deepcopy(self.data)
        altered["fault"]["long"] = {"total": 1000, "bad": 2}
        self.assertFalse(evaluate(altered)["checks"]["fault_pages"])


if __name__ == "__main__":
    unittest.main()
