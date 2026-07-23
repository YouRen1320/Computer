import copy
import json
import unittest
from pathlib import Path

from audit_claims import audit


ROOT = Path(__file__).parent


class ClaimLedgerLabTest(unittest.TestCase):
    def setUp(self) -> None:
        self.data = json.loads((ROOT / "claims.fixture.json").read_text(encoding="utf-8"))

    def test_fixture_passes(self) -> None:
        self.assertEqual([], audit(self.data))

    def test_local_evidence_cannot_be_called_production(self) -> None:
        broken = copy.deepcopy(self.data)
        broken["claims"][0]["production"] = True
        self.assertTrue(any("production" in item for item in audit(broken)))

    def test_ai_assistance_needs_human_verification(self) -> None:
        broken = copy.deepcopy(self.data)
        broken["claims"][0]["human_verification"] = ""
        self.assertTrue(any("AI work" in item for item in audit(broken)))


if __name__ == "__main__":
    unittest.main()
