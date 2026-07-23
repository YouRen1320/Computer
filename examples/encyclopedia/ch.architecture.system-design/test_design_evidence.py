import unittest

from design_evidence import SAMPLE, audit_traceability


class DesignEvidenceTest(unittest.TestCase):
    def test_capacity_units_are_reproducible(self) -> None:
        self.assertEqual(240_000, SAMPLE.daily_requests())
        self.assertEqual(40.0, SAMPLE.peak_requests_per_second())
        self.assertEqual(160_000.0, SAMPLE.peak_bytes_per_second())
        self.assertEqual(32_850_000_000, SAMPLE.retained_bytes())

    def test_components_and_failures_trace_to_constraints(self) -> None:
        packet = {
            "requirements": [{"id": "FR-1"}, {"id": "QA-1"}],
            "components": [{"id": "java-api", "requirement_ids": ["FR-1", "QA-1"]}],
            "failure_modes": [{"id": "db-down", "detect": "probe", "mitigate": "shed", "recover": "runbook"}],
            "adr": {"rejected_options": ["microservices-now"], "evolution_triggers": ["team-count>=4"]},
        }
        self.assertEqual([], audit_traceability(packet))

    def test_technology_first_component_is_rejected(self) -> None:
        packet = {
            "requirements": [{"id": "FR-1"}],
            "components": [{"id": "kafka", "requirement_ids": []}],
            "failure_modes": [],
            "adr": {"rejected_options": [], "evolution_triggers": []},
        }
        errors = audit_traceability(packet)
        self.assertTrue(any("technology-first" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
