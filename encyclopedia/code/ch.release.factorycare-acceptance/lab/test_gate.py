import copy
import json
import unittest
from pathlib import Path

from gate import audit


ROOT = Path(__file__).parent


class FactoryCareGateTest(unittest.TestCase):
    def setUp(self) -> None:
        self.report = json.loads((ROOT / "acceptance.fixture.json").read_text(encoding="utf-8"))

    def test_fixture_passes(self) -> None:
        self.assertEqual([], audit(self.report))

    def test_cache_leak_is_a_release_blocker(self) -> None:
        broken = copy.deepcopy(self.report)
        broken["security"]["cross_tenant_leaks"] = 1
        self.assertIn("tenant isolation failed", audit(broken))

    def test_ai_and_recovery_evidence_fail_closed(self) -> None:
        broken = copy.deepcopy(self.report)
        broken["ai_outage"]["core_flow"] = "blocked"
        broken["rollback"]["smoke"] = "missing"
        errors = audit(broken)
        self.assertTrue(any("AI outage" in item for item in errors))
        self.assertTrue(any("rollback" in item for item in errors))


if __name__ == "__main__":
    unittest.main()
