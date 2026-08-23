import copy
import unittest
from pathlib import Path

from log_health_lab import audit, health_state, load_fixture


class LogHealthLabTest(unittest.TestCase):
    def setUp(self) -> None:
        self.data = load_fixture(Path(__file__).with_name("telemetry-fixture.json"))

    def test_cross_layer_log_and_health_oracle(self) -> None:
        result = audit(self.data)
        self.assertTrue(result["verified"])
        self.assertEqual([], result["sensitive_findings"])

    def test_each_layer_must_reuse_the_same_correlation_id(self) -> None:
        altered = copy.deepcopy(self.data)
        altered["logs"][1]["correlation_id"] = "request-rebuilt-0002"
        self.assertFalse(audit(altered)["checks"]["correlation_continuity"])

    def test_sensitive_key_is_rejected_even_when_value_is_not_present(self) -> None:
        altered = copy.deepcopy(self.data)
        altered["logs"][0]["attributes"]["authorization"] = None
        self.assertEqual([0], audit(altered)["sensitive_findings"])

    def test_critical_dependency_changes_readiness_not_liveness(self) -> None:
        scenario = next(item for item in self.data["health_scenarios"]
                        if item["name"] == "critical-dependency-down")
        actual = health_state(scenario)
        self.assertEqual(200, actual["liveness_http"])
        self.assertEqual(503, actual["readiness_http"])


if __name__ == "__main__":
    unittest.main()
