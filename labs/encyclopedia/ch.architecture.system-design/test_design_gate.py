import unittest

from design_gate import audit, capacity, load_packet


class DesignGateTest(unittest.TestCase):
    def test_complete_synthetic_packet_passes(self) -> None:
        self.assertEqual([], audit(load_packet()))

    def test_capacity_is_reproducible_with_explicit_units(self) -> None:
        result = capacity(load_packet())
        self.assertEqual(40.0, result["peak_requests_per_second"])
        self.assertEqual(65_700_000_000, result["retained_bytes_including_replication"])

    def test_untraced_component_and_failure_success_only_are_rejected(self) -> None:
        packet = load_packet()
        packet["components"].append({"id": "kafka", "requirement_ids": []})
        packet["failure_modes"][0]["recover"] = ""
        errors = audit(packet)
        self.assertTrue(any("no requirement trace" in error for error in errors))
        self.assertTrue(any("lacks recover" in error for error in errors))

    def test_python_cannot_become_business_authority(self) -> None:
        packet = load_packet()
        packet["data_flows"][1]["business_authority"] = "python-ai"
        packet["data_flows"][1]["python_ai_data"] = "durable-business-fact"
        errors = audit(packet)
        self.assertTrue(any("Java business authority" in error for error in errors))
        self.assertTrue(any("durable business authority" in error for error in errors))

    def test_consistency_labels_require_cost_and_failure_behavior(self) -> None:
        packet = load_packet()
        packet["consistency_decisions"][1]["tradeoff"] = ""
        errors = audit(packet)
        self.assertTrue(any("lacks tradeoff" in error for error in errors))

        packet = load_packet()
        packet["consistency_decisions"] = [packet["consistency_decisions"][0]]
        errors = audit(packet)
        self.assertTrue(any("compare strong and eventual" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
